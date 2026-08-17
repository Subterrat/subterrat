from pathlib import Path
import subprocess


REPO_ROOT = Path(__file__).resolve().parents[1]
WRITER = REPO_ROOT / "deploy" / "write_flutter_env.sh"
BUILD_FRONTEND = REPO_ROOT / "deploy" / "build_frontend.sh"


def test_build_frontend_invokes_named_dockerfile(tmp_path: Path) -> None:
    assert BUILD_FRONTEND.exists(), "frontend build command is not implemented"

    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    captured_args = tmp_path / "docker-args"
    fake_docker = bin_dir / "docker"
    fake_docker.write_text(
        "#!/bin/sh\n"
        "printf '%s\\n' \"$@\" > \"$CAPTURED_DOCKER_ARGS\"\n"
    )
    fake_docker.chmod(0o755)

    result = subprocess.run(
        [str(BUILD_FRONTEND)],
        env={
            "PATH": str(bin_dir),
            "IMAGE": "asia-east1-docker.pkg.dev/example/frontend:test",
            "GOOGLE_MAPS_API_KEY": "test-browser-key",
            "CAPTURED_DOCKER_ARGS": str(captured_args),
        },
        capture_output=True,
        text=True,
        check=False,
        cwd=REPO_ROOT,
    )

    assert result.returncode == 0, result.stderr
    assert captured_args.read_text().splitlines() == [
        "build",
        "--file",
        "deploy/frontend.Dockerfile",
        "--build-arg",
        "GOOGLE_MAPS_API_KEY=test-browser-key",
        "--tag",
        "asia-east1-docker.pkg.dev/example/frontend:test",
        ".",
    ]


def test_writer_creates_flutter_env_from_build_key(tmp_path: Path) -> None:
    assert WRITER.exists(), "deployment key writer is not implemented"

    target = tmp_path / ".env"
    result = subprocess.run(
        [str(WRITER), str(target)],
        env={"GOOGLE_MAPS_API_KEY": "test-browser-key"},
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr
    assert target.read_text() == "GOOGLE_MAPS_API_KEY=test-browser-key\n"
    assert target.stat().st_mode & 0o444 == 0o444


def test_writer_rejects_placeholder_key(tmp_path: Path) -> None:
    assert WRITER.exists(), "deployment key writer is not implemented"

    result = subprocess.run(
        [str(WRITER), str(tmp_path / ".env")],
        env={"GOOGLE_MAPS_API_KEY": "YOUR_MAPS_API_KEY"},
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode != 0
