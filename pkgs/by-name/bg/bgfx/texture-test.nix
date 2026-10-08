{
  lib,
  runCommand,
  bgfx,
  libavif,
  python3,
}:

runCommand "bgfx-texture-test"
  {
    nativeBuildInputs = [
      (lib.getBin bgfx)
      libavif
      python3
    ];
  }
  ''
    mkdir -p "$out"
    cd "$out"
    python3 ${./test/check-avif.py}
  ''
