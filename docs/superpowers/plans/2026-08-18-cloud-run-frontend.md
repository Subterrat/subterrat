# Cloud Run Frontend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the current Flutter Web application as a reproducible container and deploy it as a browser-accessible Cloud Run service.

**Architecture:** A multi-stage Docker build compiles Flutter Web, then an Nginx runtime serves the generated static assets and provides SPA fallback routing. This first deployment keeps `API_BASE` empty, so the existing frontend uses its built-in demonstration data without changing the private backend API IAM policy.

**Tech Stack:** Flutter Web, Docker, Nginx, Google Cloud Build, Google Cloud Run

## Global Constraints

- Keep the existing `subterrat-hotspot-api` service private.
- Do not commit a Google Maps API key. Inject an HTTP-referrer-restricted
  browser key through the Cloud Build `_GOOGLE_MAPS_API_KEY` substitution.
- Deploy the frontend as a separate `subterrat-web` service in `asia-east1`.
- Treat deployment checks as runtime/live-provider evidence, not a trusted validation receipt.

---

### Task 1: Containerize and deploy the Flutter Web frontend

**Files:**
- Create: `.dockerignore`
- Create: `deploy/build_frontend.sh`
- Create: `deploy/cloudbuild.frontend.yaml`
- Create: `deploy/frontend.Dockerfile`
- Create: `deploy/nginx.conf.template`
- Create: `deploy/write_flutter_env.sh`
- Test: Cloud Build output and Cloud Run HTTP smoke checks

**Interfaces:**
- Consumes: Flutter entry point `lib/main.dart` and static web shell under `web/`
- Produces: Container listening on Cloud Run's `PORT`, with `/healthz` and SPA fallback at `/`

- [ ] **Step 1: Add the multi-stage Flutter/Nginx container definition**

Use the verified Cirrus stable image digest as the builder, then check out the upstream Flutter `3.47.0` tag inside it to satisfy the project's Dart `^3.13.0` constraint. Run `flutter pub get` and `flutter build web --release`. Pass the browser key as a Docker build argument and use `deploy/write_flutter_env.sh` to create the ignored `.env` build asset without writing the key to Git.

- [ ] **Step 2: Add the Nginx Cloud Run template**

Listen on `${PORT}`, serve `/usr/share/nginx/html`, return `200 ok` from `/healthz`, and fall back to `/index.html` for Flutter routes.

- [ ] **Step 3: Submit the build from the reviewed checkout**

Run Cloud Build from the reviewed feature-branch checkout in project `devjam26aug17tpe-1270`, explicitly select `deploy/frontend.Dockerfile`, tag the image in the existing `cloud-run-source-deploy` Artifact Registry repository, and require a successful build result before deployment.

- [ ] **Step 4: Deploy a separate public frontend service**

Deploy image as `subterrat-web` in `asia-east1`, allow unauthenticated access to the frontend service only, and leave `subterrat-hotspot-api` IAM unchanged.

- [ ] **Step 5: Verify the deployed artifact**

Check Cloud Run readiness, `GET /healthz` returns HTTP 200 with `ok`, `GET /` returns HTTP 200 with Flutter HTML, and the local Git worktree contains only the intentional deployment files.
