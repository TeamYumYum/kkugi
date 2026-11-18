"""Lossless PNG comparison using only the Python standard library.

RGB/RGBA/gray 8-bit non-interlaced PNGs are supported. Unsupported inputs fail;
images are never resized, aligned, blurred, or silently converted between profiles.
"""
from __future__ import annotations

import argparse
import hashlib
import html
import json
import struct
import zlib
from dataclasses import dataclass
from pathlib import Path

SIGNATURE = b"\x89PNG\r\n\x1a\n"
MAX_PIXELS = 20_000_000


@dataclass(frozen=True)
class Image:
    width: int
    height: int
    rgba: bytes
    color_metadata: tuple[tuple[bytes, bytes], ...] = ()


def paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    return a if pa <= pb and pa <= pc else b if pb <= pc else c


def read_png(path: Path) -> Image:
    data = path.read_bytes()
    if not data.startswith(SIGNATURE):
        raise ValueError(f"Not a PNG: {path.name}")
    offset = 8
    width = height = channels = 0
    compressed = bytearray()
    color_metadata = {}
    ended = False
    while offset < len(data):
        if offset + 12 > len(data):
            raise ValueError("Truncated PNG chunk")
        length, tag = struct.unpack_from(">I4s", data, offset)
        stop = offset + 12 + length
        if stop > len(data):
            raise ValueError("Truncated PNG payload")
        payload = data[offset + 8:offset + 8 + length]
        crc = struct.unpack_from(">I", data, offset + 8 + length)[0]
        if zlib.crc32(tag + payload) & 0xffffffff != crc:
            raise ValueError("PNG checksum mismatch")
        if tag == b"IHDR":
            if width or length != 13 or offset != 8:
                raise ValueError("Invalid PNG header")
            width, height, depth, kind, compression, filtering, interlace = struct.unpack(">IIBBBBB", payload)
            if not 0 < width * height <= MAX_PIXELS or depth != 8 or compression or filtering or interlace:
                raise ValueError("Require bounded 8-bit non-interlaced PNG")
            channels = {0: 1, 2: 3, 4: 2, 6: 4}.get(kind, 0)
            if not channels:
                raise ValueError("Unsupported PNG color type")
        elif tag == b"IDAT":
            if not channels:
                raise ValueError("Missing PNG header")
            compressed.extend(payload)
        elif tag in {b"iCCP", b"gAMA", b"cHRM", b"sRGB", b"cICP", b"mDCV", b"cLLI"}:
            # Fail closed on different encoded color interpretations. Do not
            # silently strip metadata or convert the original pixel samples.
            if tag in color_metadata:
                raise ValueError("Duplicate PNG color metadata")
            color_metadata[tag] = payload
        elif tag == b"tRNS":
            raise ValueError("Require explicit alpha, not tRNS transparency")
        elif tag == b"IEND":
            ended = True
            if length or stop != len(data):
                raise ValueError("Invalid PNG end")
            break
        elif tag[0] & 32 == 0:
            raise ValueError(f"Unsupported critical PNG chunk: {tag!r}")
        offset = stop
    if not ended or not width or not height or not compressed:
        raise ValueError("Incomplete PNG")
    stride = width * channels
    expected = (stride + 1) * height
    decoder = zlib.decompressobj()
    raw = decoder.decompress(compressed, expected + 1)
    if len(raw) != expected or not decoder.eof or decoder.unused_data:
        raise ValueError("Invalid or oversized PNG pixel stream")
    previous = bytearray(stride)
    rgba = bytearray()
    for y in range(height):
        start = y * (stride + 1)
        filter_type = raw[start]
        if filter_type > 4:
            raise ValueError("Unknown PNG row filter")
        row = bytearray(raw[start + 1:start + stride + 1])
        for x in range(stride):
            left = row[x - channels] if x >= channels else 0
            up = previous[x]
            upper_left = previous[x - channels] if x >= channels else 0
            predictor = (0, left, up, (left + up) // 2, paeth(left, up, upper_left))[filter_type]
            row[x] = (row[x] + predictor) & 255
        for x in range(0, stride, channels):
            if channels == 4:
                rgba.extend(row[x:x + 4])
            elif channels == 3:
                rgba.extend(row[x:x + 3]); rgba.append(255)
            else:
                rgba.extend([row[x]] * 3 + [row[x + 1] if channels == 2 else 255])
        previous = row
    return Image(width, height, bytes(rgba), tuple(sorted(color_metadata.items())))


def chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)


def write_png(path: Path, image: Image) -> None:
    if len(image.rgba) != image.width * image.height * 4:
        raise ValueError("RGBA length does not match dimensions")
    rows = b"".join(b"\0" + image.rgba[y * image.width * 4:(y + 1) * image.width * 4] for y in range(image.height))
    path.write_bytes(SIGNATURE + chunk(b"IHDR", struct.pack(">IIBBBBB", image.width, image.height, 8, 6, 0, 0, 0))
                     + chunk(b"sRGB", b"\0") + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b""))


def compare(reference: Path, candidate: Path, output: Path) -> dict:
    if reference.resolve() == candidate.resolve():
        raise ValueError("Reference and candidate must be different files")
    ref = read_png(reference)
    actual = read_png(candidate)
    if (ref.width, ref.height) != (actual.width, actual.height):
        raise ValueError("Image sizes differ; automatic resizing is forbidden")
    if ref.color_metadata != actual.color_metadata:
        raise ValueError("PNG color metadata differ; establish matching capture color information before comparing")
    if output.exists():
        raise ValueError("Output already exists; choose a new comparison directory")
    output.mkdir(parents=True)
    count = ref.width * ref.height
    changed = 0
    sums = [0] * 4
    maxima = [0] * 4
    bounds = [ref.width, ref.height, -1, -1]
    difference = bytearray()
    overlay = bytearray()
    side_by_side = bytearray()
    for offset in range(0, len(ref.rgba), 4):
        a = ref.rgba[offset:offset + 4]
        b = actual.rgba[offset:offset + 4]
        delta = [abs(x - y) for x, y in zip(a, b)]
        if any(delta):
            changed += 1
            index = offset // 4
            x, y = index % ref.width, index // ref.width
            bounds = [min(bounds[0], x), min(bounds[1], y), max(bounds[2], x), max(bounds[3], y)]
        for c in range(4):
            sums[c] += delta[c]; maxima[c] = max(maxima[c], delta[c])
        difference.extend(delta[:3] + [255])
        overlay.extend([(a[c] + b[c]) // 2 for c in range(4)])
    for y in range(ref.height):
        start, stop = y * ref.width * 4, (y + 1) * ref.width * 4
        side_by_side.extend(ref.rgba[start:stop] + actual.rgba[start:stop])
    # Preserve original PNG bytes, including original metadata.
    (output / "android.png").write_bytes(reference.read_bytes())
    (output / "ios.png").write_bytes(candidate.read_bytes())
    write_png(output / "difference.png", Image(ref.width, ref.height, bytes(difference)))
    write_png(output / "overlay.png", Image(ref.width, ref.height, bytes(overlay)))
    write_png(output / "side-by-side.png", Image(ref.width * 2, ref.height, bytes(side_by_side)))
    report = {
        "status": "identical" if changed == 0 else "differences-found",
        "width": ref.width, "height": ref.height, "pixels": count, "changedPixels": changed,
        "changedFraction": changed / count, "meanAbsoluteRGBA": [s / count for s in sums],
        "maxAbsoluteRGBA": maxima, "changedBoundsInclusive": bounds if changed else None,
        "referenceSha256": hashlib.sha256(reference.read_bytes()).hexdigest(),
        "candidateSha256": hashlib.sha256(candidate.read_bytes()).hexdigest(),
        "resized": False, "blurred": False, "masked": False,
        "alphaIncludedInMetrics": True, "differenceImage": "absolute RGB, opaque alpha",
        "tolerance": 0, "approvedExceptions": [],
    }
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    summary = html.escape(json.dumps(report, indent=2))
    (output / "index.html").write_text(
        '<!doctype html><meta charset="utf-8"><title>꾸기 픽셀 비교</title>'
        '<style>body{font-family:system-ui;margin:24px}img{max-width:100%;border:1px solid #ccc}pre{white-space:pre-wrap}</style>'
        '<h1>Android · iOS 픽셀 비교</h1><p>원본 크기로 비교했습니다. 차이가 있으면 일치 판정을 내리지 않습니다.</p>'
        '<h2>나란히 보기</h2><img src="side-by-side.png" alt="Android 왼쪽, iOS 오른쪽">'
        '<h2>50% 겹침</h2><img src="overlay.png" alt="겹침">'
        '<h2>절대 RGB 차이</h2><img src="difference.png" alt="차이"><pre>' + summary + '</pre>', encoding="utf-8")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", required=True, type=Path)
    parser.add_argument("--candidate", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    try:
        result = compare(args.reference, args.candidate, args.output)
    except (ValueError, OSError, zlib.error) as error:
        parser.exit(2, f"Comparison failed: {error}\n")
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result["status"] == "identical" else 1)


if __name__ == "__main__":
    main()
