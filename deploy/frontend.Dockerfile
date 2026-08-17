FROM ghcr.io/cirruslabs/flutter:stable@sha256:46691e311715845de03a3ba4753a475476936805b29431b1f00f1816981033f8 AS build

RUN git -C "$FLUTTER_ROOT" fetch --depth 1 origin tag 3.47.0 \
    && git -C "$FLUTTER_ROOT" checkout 3.47.0 \
    && flutter --version

WORKDIR /workspace

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

ARG GOOGLE_MAPS_API_KEY
COPY . .
RUN ./deploy/write_flutter_env.sh .env \
    && flutter build web --release

FROM nginx:alpine

COPY deploy/nginx.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /workspace/build/web /usr/share/nginx/html

EXPOSE 8080
