# Building Only minarch.elf (Audio Fix)

## What Binary to Rebuild

The audio fix is in `workspace/all/common/api.c`, which is compiled into:
- **`minarch.elf`** - The libretro emulator launcher (this is what you need)

**Output location**: `workspace/all/minarch/build/tg5040/minarch.elf`

## Quick Build (Docker - Recommended)

**Option 1: Use the build script (Easiest)**

From the project root:

```bash
./build-minarch-only.sh
```

Or specify platform:
```bash
PLATFORM=tg5040 ./build-minarch-only.sh
```

**Option 2: Manual Docker build**

From the project root:

```bash
# Build only minarch using Docker
docker run --rm \
  -v "$(pwd)/workspace:/root/workspace" \
  ghcr.io/loveretro/tg5040-toolchain:latest \
  /bin/bash -c ". ~/.bashrc && cd /root/workspace/all/minarch && make PLATFORM=tg5040"
```

**Option 3: Interactive Docker shell**

```bash
make PLATFORM=tg5040 shell
# Inside Docker container:
cd /root/workspace/all/minarch
make PLATFORM=tg5040
exit
```

The binary will be at: `workspace/all/minarch/build/tg5040/minarch.elf`

## Alternative: Direct Build (if toolchain is set up)

If you have the cross-compilation toolchain set up locally:

```bash
cd workspace/all/minarch
make PLATFORM=tg5040
```

## What Gets Built

The `minarch` makefile compiles:
- `minarch.c` (main emulator launcher)
- `../common/api.c` ← **Your audio fix is here**
- `../common/scaler.c`
- `../common/utils.c`
- `../common/config.c`
- `../../tg5040/platform/platform.c`

## After Building

1. **Copy the binary**:
   ```bash
   cp workspace/all/minarch/build/tg5040/minarch.elf /path/to/your/update/folder/
   ```

2. **Or use your update script**:
   ```bash
   ./collect-update-files.sh
   # This will collect minarch.elf into tg5040-update/
   ```

## Verification

After building, check the binary was updated:
```bash
ls -lh workspace/all/minarch/build/tg5040/minarch.elf
```

The modification time should be recent.

