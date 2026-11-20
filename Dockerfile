# Portable headless validation/export image for macOS and Linux hosts.
# The official Docker Hub image is not published for this engine version, so
# download the pinned upstream Godot release binary directly.
FROM ubuntu:24.04

ARG GODOT_VERSION=4.7.2
ARG TARGETARCH
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates curl unzip libfontconfig1 libgl1 libx11-6 libxcursor1 libxi6 libxinerama1 libxrandr2 libasound2t64 \
    && ARCH="$(test "$TARGETARCH" = amd64 && echo x86_64 || echo "$TARGETARCH")" \
    && curl -fsSL -o /tmp/godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.${ARCH}.zip" \
    && unzip -q /tmp/godot.zip -d /tmp/godot \
    && install -m 0755 /tmp/godot/Godot_v${GODOT_VERSION}-stable_linux.${ARCH} /usr/local/bin/godot \
    && rm -rf /tmp/godot /tmp/godot.zip /var/lib/apt/lists/*

WORKDIR /app
COPY . /app

# The image is intentionally headless: graphical builds remain platform-specific.
ENTRYPOINT ["godot", "--headless", "--path", "."]
CMD ["--script", "res://scripts/headless/main.gd", "--", "--seed", "123", "--night", "1", "--ticks", "600", "--out", "/tmp/lantern.jsonl"]
