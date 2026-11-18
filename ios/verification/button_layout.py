"""Compare measured button edges in content pixels for an animated screen."""
import argparse
import json
from pathlib import Path


def validate(data):
    width, height = data["viewport"]
    if not all(type(v) is int and v > 0 for v in (width, height)):
        raise ValueError("Invalid viewport")
    if not data["case"] or not isinstance(data["buttons"], dict) or not data["buttons"]:
        raise ValueError("Missing screen state or measured buttons")
    for name, rect in data["buttons"].items():
        if not name or len(rect) != 4 or not all(type(v) is int for v in rect):
            raise ValueError(f"Invalid bounds for {name}")
        left, top, right, bottom = rect
        if not (0 <= left < right <= width and 0 <= top < bottom <= height):
            raise ValueError(f"Empty or out-of-viewport bounds for {name}")


def compare(reference, candidate):
    validate(reference)
    validate(candidate)
    if any(reference[k] != candidate[k] for k in ("case", "viewport")):
        raise ValueError("State or viewport differs")
    expected, measured = reference["buttons"], candidate["buttons"]
    changed = {
        key: {"android": expected.get(key), "ios": measured.get(key)}
        for key in sorted(expected.keys() | measured.keys()) if expected.get(key) != measured.get(key)
    }
    return {"case": reference["case"], "viewport": reference["viewport"], "changed": changed,
            "status": "different" if changed else "identical"}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("android", type=Path)
    parser.add_argument("ios", type=Path)
    args = parser.parse_args()
    try:
        if args.android.samefile(args.ios):
            raise ValueError("Reference and candidate must be separate measurements")
        result = compare(*(json.loads(p.read_text(encoding="utf-8")) for p in (args.android, args.ios)))
    except (OSError, KeyError, TypeError, ValueError) as error:
        parser.exit(2, f"Cannot compare measurements: {error}\n")
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result["status"] == "identical" else 1)
