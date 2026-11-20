# Release v1.0.0

The portable release route is a Docker image containing the deterministic Godot 4.7.2 headless runner. It works on macOS or Linux hosts running Docker Desktop/Engine and does not require a GPU. Its Dockerfile pins and downloads the matching upstream Godot 4.7.2 Linux `arm64` or `x86_64` binary during the build.

```bash
docker build -t dao-den-long:v1.0.0 .
docker run --rm dao-den-long:v1.0.0
```

The default container writes its sample JSONL to `/tmp/lantern.jsonl`. Mount an output directory for a retained artifact:

```bash
docker run --rm -v "$PWD/out:/out" dao-den-long:v1.0.0 \
  --script res://scripts/headless/main.gd -- --seed 123 --night 1 --ticks 600 --out /out/lantern.jsonl
```

For GitHub submission, create release `v1.0.0`, attach the exported Docker image (`docker save`) or a platform build, and publish this repository tag. The image build must be performed after Docker Desktop/Engine is running.
