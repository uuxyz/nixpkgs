"""Exercise texturec's AVIF decoder with a generated lossless RGB fixture."""

from pathlib import Path
import struct
import subprocess
import zlib


def chunk(kind, data):
    return (
        struct.pack(">I", len(data))
        + kind
        + data
        + struct.pack(">I", zlib.crc32(kind + data))
    )


# A small solid image makes the expected pixels independent of row orientation.
width, height = 4, 4
rgb = bytes((192, 64, 32))
Path("input.png").write_bytes(
    b"\x89PNG\r\n\x1a\n"
    + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    + chunk(b"IDAT", zlib.compress((b"\0" + rgb * width) * height))
    + chunk(b"IEND", b"")
)
subprocess.run(
    ["avifenc", "--lossless", "--jobs", "1", "input.png", "input.avif"], check=True
)
subprocess.run(
    [
        "bgfx-texturec",
        "-f",
        "input.avif",
        "-o",
        "output.dds",
        "-t",
        "RGBA8",
        "--linear",
    ],
    check=True,
)

data = Path("output.dds").read_bytes()
assert data[:4] == b"DDS ", "texturec did not produce a DDS image"
assert struct.unpack_from("<I", data, 4)[0] == 124, "invalid DDS header size"
assert struct.unpack_from("<II", data, 12) == (
    height,
    width,
), "wrong decoded dimensions"
# texturec writes a legacy DDS header for RGBA8. Verify its channel masks
# before interpreting the payload as tightly packed RGBA pixels.
assert data[84:88] == b"\0" * 4, "expected an uncompressed DDS image"
assert struct.unpack_from("<6I", data, 80) == (
    0x41,
    0,
    32,
    0xFF,
    0xFF00,
    0xFF0000,
), "unexpected DDS pixel format"
assert struct.unpack_from("<I", data, 104)[0] == 0xFF000000, "wrong alpha mask"
pixels = data[128:]
assert pixels == (rgb + b"\xff") * (width * height), "AVIF pixels did not round-trip"
print("PASS: lossless AVIF decoded to the expected RGBA8 pixels")
