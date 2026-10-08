{
  stdenv,
  cmake,
  ninja,
  bgfx,
}:

stdenv.mkDerivation {
  pname = "bgfx-consumer-test";
  inherit (bgfx) version;
  src = ./test;
  strictDeps = true;

  nativeBuildInputs = [
    cmake
    ninja
  ];
  buildInputs = [ bgfx ];

  installPhase = ''
    runHook preInstall
    install -Dm755 consumer $out/bin/bgfx-consumer-test
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/bgfx-consumer-test
    runHook postInstallCheck
  '';
}
