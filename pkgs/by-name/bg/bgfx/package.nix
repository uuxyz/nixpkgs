{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  libGL,
  libx11,
  libxcb,
  wayland,
  vulkan-loader,
  directx-shader-compiler,
  glslang,
  spirv-tools,
  spirv-cross,
  meshoptimizer,
  callPackage,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "bgfx";
  version = "unstable-2026-10-08";

  # Upstream's CMake project pins a compatible set of bgfx, bx and bimg.
  src = fetchFromGitHub {
    owner = "bkaradzic";
    repo = "bgfx.cmake";
    rev = "a0649dcc72ca1dc9fb7ac58e257ae2340be3d070";
    fetchSubmodules = true;
    hash = "sha256-I9HJxnJJapDshch+M80/kQfmWKKpJazSvFrrrHnqqE8=";
  };

  outputs = [
    "out"
    "dev"
    "bin"
  ];
  strictDeps = true;

  patches = [ ./glslang-public-api.patch ];

  nativeBuildInputs = [
    cmake
    ninja
  ];

  buildInputs = [
    libxcb
    wayland
    glslang
    spirv-tools
    spirv-cross
    meshoptimizer
  ];

  # The exported CMake target links consumers against these libraries.
  propagatedBuildInputs = [
    libGL
    libx11
  ];

  # These backends load their libraries at runtime rather than linking them.
  postPatch = ''
    substituteInPlace bgfx/src/renderer_vk.cpp \
      --replace-fail '"libvulkan.so.1"' '"${lib.getLib vulkan-loader}/lib/libvulkan.so.1"'
    substituteInPlace bgfx/src/glcontext_egl.cpp \
      --replace-fail '"libEGL.so.1"' '"${lib.getLib libGL}/lib/libEGL.so.1"' \
      --replace-fail '"libGL.so.1"' '"${lib.getLib libGL}/lib/libGL.so.1"' \
      --replace-fail '"libGLESv2.so.2"' '"${lib.getLib libGL}/lib/libGLESv2.so.2"' \
      --replace-fail '"libwayland-egl.so.1"' '"${lib.getLib wayland}/lib/libwayland-egl.so.1"'

    # Use the source-built DXC package instead of upstream's bundled binary.
    substituteInPlace cmake/bgfx/shaderc.cmake \
      --replace-fail 'set(DXCOMPILER_RUNTIME ''${BGFX_DIR}/tools/bin/linux/libdxcompiler.so)' 'set(DXCOMPILER_RUNTIME)'
    substituteInPlace bgfx/tools/shaderc/shaderc_dxil.cpp \
      --replace-fail '"libdxcompiler.so"' '"${lib.getLib directx-shader-compiler}/lib/libdxcompiler.so"' \
      --replace-fail 'bx::dlopen(dxcCompilerDll.getCPtr() )' 'bx::dlopen(dxcCompilerDllName)'

    cp ${./system-shader-libraries.cmake} cmake/bgfx/system-shader-libraries.cmake
    substituteInPlace cmake/bgfx/CMakeLists.txt \
      --replace-fail 'include(3rdparty/spirv-opt.cmake)' 'include(system-shader-libraries.cmake)' \
      --replace-fail 'include(3rdparty/spirv-cross.cmake)' "" \
      --replace-fail 'include(3rdparty/glslang.cmake)' ""
    substituteInPlace bgfx/tools/geometryc/geometryc.cpp \
      --replace-fail '<meshoptimizer/src/meshoptimizer.h>' '<meshoptimizer.h>'
    substituteInPlace cmake/bgfx/geometryc.cmake \
      --replace-fail 'PRIVATE ''${MESHOPTIMIZER_INCLUDE_DIR}' 'PRIVATE ''${MESHOPTIMIZER_INCLUDE_DIR} ''${BGFX_DIR}/3rdparty'
  '';

  cmakeFlags = [
    (lib.cmakeFeature "BGFX_LIBRARY_TYPE" "SHARED")
    (lib.cmakeBool "CMAKE_POSITION_INDEPENDENT_CODE" true)
    (lib.cmakeBool "BGFX_BUILD_EXAMPLES" false)
    (lib.cmakeBool "BGFX_BUILD_TOOLS" true)
    (lib.cmakeFeature "BGFX_TOOLS_PREFIX" "bgfx-")
    (lib.cmakeFeature "MESHOPTIMIZER_LIBRARIES" "${lib.getLib meshoptimizer}/lib/libmeshoptimizer.so")
    (lib.cmakeFeature "MESHOPTIMIZER_INCLUDE_DIR" "${lib.getDev meshoptimizer}/include")
    (lib.cmakeBool "BGFX_CUSTOM_TARGETS" false)
  ];

  postInstall = ''
    (
      cd "$src"
      install -Dm644 LICENSE $out/share/licenses/bgfx/bgfx.cmake/LICENSE
      find bgfx bx bimg -type f \( \
        -iname 'license*' -o -iname 'copying*' -o -iname 'notice*' -o -iname 'unlicense*' \
      \) -exec install -Dm644 {} $out/share/licenses/bgfx/{} \;
    )
  '';

  passthru.tests = {
    consumer = callPackage ./test.nix {
      bgfx = finalAttrs.finalPackage;
    };
    shaders = callPackage ./shader-test.nix {
      bgfx = finalAttrs.finalPackage;
    };
  };

  meta = {
    description = "Cross-platform rendering library with multiple graphics backends";
    homepage = "https://github.com/bkaradzic/bgfx";
    license = with lib.licenses; [
      bsd2
      bsd3
      asl20
      mit
      cc0
    ];
    maintainers = [ lib.maintainers.uuxyz ];
    platforms = lib.platforms.linux;
    mainProgram = "bgfx-shaderc";
    outputsToInstall = [
      "out"
      "bin"
    ];
  };
})
