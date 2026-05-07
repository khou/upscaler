# Upscaler

A drag-and-drop image upscaler for macOS. Drop PNG/JPEG/WebP images on the app
icon and get higher-resolution copies powered by Real-ESRGAN. By default it
auto-picks the upscale factor per image (2x/3x/4x) so the output is big enough
for KDP print at 300 DPI on 8.5x11" (2550x3300 px), falling back to 4x if the
input is too small to reach that. You can also force a fixed factor.

No subscription, no telemetry, no internet connection required after install.

## Install (prebuilt)

1. Download the latest `Upscaler.zip` from [Releases](../../releases).
2. Unzip and move `Upscaler.app` to `/Applications`.
3. First launch: right-click the app → **Open** (it's ad-hoc signed, not
   notarized, so Gatekeeper asks once).

## Use

- Drag images onto the app icon, or double-click the app and pick files.
- Pick **Auto** (default, targets KDP 8.5x11 at 300 DPI) or a fixed 2x/3x/4x.
- Choose where to save the output.
- Wait. Each image is saved as `<name>_x<scale>.png`. In Auto mode the scale
  in the filename reflects what was actually chosen for that image.

## Build from source

Requires macOS with command line tools (no Xcode needed).

```sh
git clone https://github.com/khou/upscaler.git
cd upscaler
bash scripts/fetch-engine.sh   # downloads upscayl-bin + Real-ESRGAN models
bash scripts/make-droplet.sh   # produces build/Upscaler.app
open build/Upscaler.app
```

## How it works

`Upscaler.app` is an AppleScript droplet that bundles the
[upscayl-ncnn](https://github.com/upscayl/upscayl-ncnn) inference binary and
[Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN) model weights inside its
`Contents/Resources/engine/` directory. When you drop an image, the script
shells out to the bundled binary, which runs the model on your GPU via Vulkan
(MoltenVK on macOS).

Universal binary, so the same `.app` runs natively on both Apple Silicon and
Intel Macs.

## Licensing

The wrapper code in this repository is MIT-licensed (see [LICENSE](LICENSE)).

The bundled inference binary is **AGPLv3** (from the upscayl-ncnn project), so
any `.app` you build or distribute carries the AGPL obligations of that
binary. If you redistribute the built app you must comply with AGPLv3 for the
bundled engine. The Real-ESRGAN model weights are BSD 3-Clause.

If you want to distribute commercially without AGPL obligations, swap the
engine for either the original Real-ESRGAN ncnn binary (BSD 3-Clause, older,
Intel-only on macOS) or your own ncnn build, and update `scripts/fetch-engine.sh`
accordingly.

## Why AppleScript

The first version was a SwiftUI app; it ran into a Swift toolchain skew on
Command Line Tools that needs a full Xcode install or a CLT update to fix. An
AppleScript droplet builds with `osacompile`, which is part of every macOS
install, so anyone can build this repo without installing anything extra.

A native rewrite (likely Rust + egui or Tauri, with on-device ONNX inference
via Core ML) is on the roadmap.
