#!/usr/bin/env python3
"""Generate a safe easymcp create command."""

import argparse
import shlex


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("name")
    parser.add_argument("openapi")
    parser.add_argument("--port", type=int, default=8091)
    parser.add_argument("--group", default="")
    parser.add_argument("--image", default="ab0tcom/easymcp:v0.1.0")
    args = parser.parse_args()

    command = [
        "easymcp",
        "create",
        args.name,
        "--openapi",
        args.openapi,
        "--port",
        str(args.port),
        "--image",
        args.image,
    ]
    if args.group:
        command.extend(["--group", args.group])
    print(" ".join(shlex.quote(part) for part in command))


if __name__ == "__main__":
    main()
