# Sententia

OpenClaw container with Playwright, kubectl, git, Python, Java, and FFmpeg.

## Manual Build & Push

The GitHub Action builds on push to main, but if you need to do it manually:

```bash
# Login to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin

# Build for ARM64 (Raspberry Pi)
docker buildx build --platform linux/arm64 -t ghcr.io/albindalbert/sententia:latest --push .

# Or build for local architecture (testing)
docker build -t sententia:local .
```

