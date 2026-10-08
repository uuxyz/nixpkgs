{
  lib,
  stdenv,
  runCommand,
  bgfx,
}:

runCommand "bgfx-shader-test"
  {
    nativeBuildInputs = [ (lib.getBin bgfx) ];
  }
  (
    ''
      mkdir -p $out
      for profile in 330 spirv wgsl metal; do
        platform=linux
        if [ "$profile" = metal ]; then
          platform=osx
        fi
        for stage in vertex fragment; do
          if [ "$stage" = vertex ]; then
            source=${./test/vertex.sc}
            magic=VSH
          else
            source=${./test/fragment.sc}
            magic=FSH
          fi
          echo "Compiling $stage shader: $profile ($platform)"
          output=$out/$stage-$profile.bin
          bgfx-shaderc -f "$source" -o "$output" \
            --type "$stage" --platform "$platform" -p "$profile" \
            --varyingdef ${./test/varying.def.sc} \
            -i ${lib.getDev bgfx}/include/bgfx
          test "$(head -c 3 "$output")" = "$magic"
        done
      done

    ''
    + lib.optionalString stdenv.hostPlatform.isLinux ''
      # Exercise the source-built DXC runtime on Linux as well.
      bgfx-shaderc -f ${./test/vertex.sc} -o $out/vertex-dxil.bin \
        --type vertex --platform windows -p s_6_0 \
        --varyingdef ${./test/varying.def.sc} \
        -i ${lib.getDev bgfx}/include/bgfx
      test "$(head -c 3 $out/vertex-dxil.bin)" = VSH
    ''
  )
