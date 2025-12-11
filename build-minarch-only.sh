#!/bin/bash
# Build only minarch.elf using Docker (with dependencies)

set -e

PLATFORM=${PLATFORM:-tg5040}
HOST_WORKSPACE=$(pwd)/workspace
GUEST_WORKSPACE=/root/workspace
IMAGE_NAME=ghcr.io/loveretro/${PLATFORM}-toolchain:latest

echo "Building minarch.elf for $PLATFORM..."
echo "Using Docker image: $IMAGE_NAME"
echo ""

# Build dependencies first (wifimanager provides wifid_cmd.h)
# Build order matches workspace/makefile
docker run --rm \
  -v "$HOST_WORKSPACE:$GUEST_WORKSPACE" \
  "$IMAGE_NAME" \
  /bin/bash -c "
    . ~/.bashrc && \
    cd /root/workspace && \
    cd ./$PLATFORM/wifimanager && make all && \
    cd ../libmsettings && make && \
    cd ../../all/minarch && make PLATFORM=$PLATFORM
  "

echo ""
echo "✓ Build complete!"
echo "Binary location: workspace/all/minarch/build/$PLATFORM/minarch.elf"

