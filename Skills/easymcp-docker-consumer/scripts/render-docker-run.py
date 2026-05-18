#!/usr/bin/env python3
"""Generate a safe docker run command for the EasyMCP image."""

import argparse
import shlex
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("config")
    parser.add_argument("--name", default="easymcp-service")
    parser.add_argument("--image", default="ab0tcom/easymcp:v0.1.0")
    parser.add_argument("--host-port", type=int, default=8000)
    parser.add_argument("--container-port", type=int, default=8000)
    parser.add_argument("--env", action="append", default=[], help="Env var name to pass through")
    args = parser.parse_args()

    config = Path(args.config)
    command = [
        "docker",
        "run",
        "--rm",
        "--name",
        args.name,
        "-p",
        f"{args.host_port}:{args.container_port}",
    ]
    for env in args.env:
        command.extend(["-e", env])
    command.extend([
        "-v",
        f"{config}:/app/config.yaml:ro",
        args.image,
        "/app/config.yaml",
    ])
    print(" ".join(shlex.quote(part) for part in command))


if __name__ == "__main__":
    main()
