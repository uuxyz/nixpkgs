from pathlib import Path
import json
import struct
import subprocess
import sys

# Read the serialized reflection consumed by renderer_webgpu.cpp, not just
# the compiler's exit code. Fixtures cover the public-glslang-API patch.
includes, varying, output_dir = sys.argv[1:]
root = Path(output_dir)
root.mkdir()
shaderc = "bgfx-shaderc"
cases = [
    ("none", "", "v_color0", {}, 0),
    ("vec4", "uniform vec4 u_tint;", "v_color0 * u_tint", {"u_tint": (2, 1, 0, 1)}, 16),
    (
        "unused",
        "uniform vec4 u_unused;\nuniform vec4 u_tint;",
        "v_color0 * u_tint",
        {"u_tint": (2, 1, 0, 1)},
        16,
    ),
    (
        "array",
        "uniform vec4 u_colors[2];",
        "v_color0 * u_colors[0] + u_colors[1]",
        {"u_colors": (2, 2, 0, 2)},
        32,
    ),
    (
        "mat3",
        "uniform mat3 u_matrix;",
        "vec4(mul(u_matrix, v_color0.xyz), 1.0)",
        {"u_matrix": (3, 1, 0, 3)},
        48,
    ),
    (
        "mixed",
        "uniform mat4 u_transform;\nuniform vec4 u_colors[2];\nuniform vec4 u_tint;",
        "mul(u_transform, v_color0) * u_colors[0] + u_colors[1] * u_tint",
        {
            "u_transform": (4, 1, 0, 4),
            "u_colors": (2, 2, 64, 2),
            "u_tint": (2, 1, 96, 1),
        },
        112,
    ),
    ("sampler_only", "SAMPLER2D(s_tex, 0);", "texture2D(s_tex, v_color0.xy)", {}, 0),
    (
        "sampler_uniform",
        "SAMPLER2D(s_tex, 0);\nuniform vec4 u_tint;",
        "texture2D(s_tex, v_color0.xy) * u_tint",
        {"u_tint": (2, 1, 0, 1)},
        16,
    ),
]
results = []
for name, decl, expr, expected, expected_block in cases:
    source = root / (name + ".sc")
    output = root / (name + ".bin")
    source.write_text(
        "$input v_color0\n#include <bgfx_shader.sh>\n"
        + decl
        + "\nvoid main() { gl_FragColor = "
        + expr
        + "; }\n"
    )
    run = subprocess.run(
        [
            shaderc,
            "-f",
            str(source),
            "-o",
            str(output),
            "--type",
            "fragment",
            "--platform",
            "linux",
            "-p",
            "wgsl",
            "--varyingdef",
            varying,
            "-i",
            includes,
        ],
        capture_output=True,
        text=True,
    )
    (root / (name + ".log")).write_text(run.stdout + run.stderr)
    assert run.returncode == 0, (name, run.stdout, run.stderr)
    d = output.read_bytes()
    assert d[:4] == b"FSH\x0c"
    # Magic, two interface hashes, and two raw-resource binding masks.
    offset = 4 + 8 + 8
    (uniform_count,) = struct.unpack_from("<H", d, offset)
    offset += 2
    uniforms = {}
    all_uniforms = {}
    for _ in range(uniform_count):
        size = d[offset]
        offset += 1
        uname = d[offset : offset + size].decode()
        offset += size
        typ, num, reg, reg_count, component, dimension, fmt = struct.unpack_from(
            "<BBHHBBH", d, offset
        )
        offset += 10
        all_uniforms[uname] = (typ, num, reg, reg_count)
        if (typ & 0xF) in (2, 3, 4):  # Vec4, Mat3, Mat4; exclude samplers.
            uniforms[uname] = (typ & 0xF, num, reg, reg_count)
    (size,) = struct.unpack_from("<I", d, offset)
    offset += 4
    code = d[offset : offset + size].decode()
    (root / (name + ".wgsl")).write_text(code)
    offset += size + 1
    attrs = d[offset]
    offset += 1 + attrs * 2
    uniform_size, block_size = struct.unpack_from("<HH", d, offset)
    offset += 4
    assert offset == len(d), (name, "unexpected trailing data")
    result = dict(
        case=name,
        uniforms=uniforms,
        all_uniforms=all_uniforms,
        uniform_size=uniform_size,
        block_size=block_size,
    )
    results.append(result)
    print(json.dumps(result), flush=True)
    assert uniforms == expected, (name, uniforms, expected)
    assert block_size == expected_block, (name, block_size, expected_block)
    assert uniform_size == expected_block, (name, uniform_size, expected_block)
(root / "results.json").write_text(json.dumps(results, indent=2) + "\n")
print("PASS: all 8 WGSL reflection cases")
