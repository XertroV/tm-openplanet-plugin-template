#!/usr/bin/env python3

import argparse
import os
import platform
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

# Use the built-in tomllib if available (Python 3.11+), else use tomli
try:
    import tomllib
except ImportError:
    import tomli as tomllib


class Colors:
    """A simple class for printing colored text to the console."""
    RED = "\033[91m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    END = "\033[0m"

    @staticmethod
    def print(color, text):
        # Modern Windows terminals support ANSI codes.
        print(f"{color}{text}{Colors.END}")


def get_plugins_dir() -> Path:
    """
    Determines the Openplanet plugins directory.
    Prioritizes the PLUGINS_DIR environment variable.
    Falls back to a default based on the operating system.
    """
    if "PLUGINS_DIR" in os.environ:
        return Path(os.environ["PLUGINS_DIR"])
    return Path.home() / "OpenplanetNext" / "Plugins"
    # if platform.system() == "Windows":
    #     return Path.home() / "OpenplanetNext" / "Plugins"
    # else:
    #     return Path.home() / "OpenplanetNext" / "Plugins"


def get_remote_build_ip() -> str:
    if platform.system() == "Windows":
        return "127.0.0.1"
    # WSL host system address. You may need to adjust this based on your WSL configuration.
    return "172.18.16.1"


def run_command(command, check=True):
    """Runs a command and optionally checks for errors."""
    try:
        subprocess.run(command, check=check, shell=False)
    except FileNotFoundError:
        Colors.print(Colors.RED, f"⚠ Error: Command not found: {command[0]}")
        sys.exit(1)
    except subprocess.CalledProcessError as e:
        Colors.print(Colors.RED, f"⚠ Error running command: {' '.join(command)}")
        sys.exit(e.returncode)


def print_copied(copied: Path):
    for item in copied.iterdir():
        if item.is_dir():
            print_copied(item)  # Recursively print directories
        else:
            print(f"Copied: {item}")


def main():
    """Main build script execution."""
    parser = argparse.ArgumentParser(
        description="Build script for Openplanet plugins."
    )
    parser.add_argument(
        "build_mode",
        nargs="?",
        default="dev",
        choices=["dev", "release", "prerelease", "unittest"],
        help="The build mode (defaults to 'dev').",
    )
    args = parser.parse_args()
    build_mode = args.build_mode

    Colors.print(Colors.YELLOW, f"🚩 Build mode: {build_mode}")

    if build_mode == "release" and not shutil.which("7z"):
        Colors.print(Colors.RED, "⚠ Error: '7z' command not found, but is required for release builds.")
        Colors.print(Colors.YELLOW, "Please install 7-Zip and ensure '7z' is in your system's PATH.")
        sys.exit(1)

    # --- Configuration ---
    plugin_src_dir = Path("src")
    info_toml_path = Path("info.toml")
    license_path = Path("LICENSE")
    readme_path = Path("README.md")

    if not info_toml_path.exists():
        Colors.print(Colors.RED, f"⚠ Error: '{info_toml_path}' not found.")
        sys.exit(1)

    # --- Parse info.toml ---
    with open(info_toml_path, "rb") as f:
        info = tomllib.load(f)
    meta = info['meta']
    plugin_pretty_name = meta["name"]
    plugin_version = meta["version"]

    if len(plugin_pretty_name) < 2:
        Colors.print(Colors.RED, f"⚠ Error: Plugin name is too short. Name = '{plugin_pretty_name}' (length: {len(plugin_pretty_name)})")
        sys.exit(1)

    # --- Adjust names based on build mode ---
    suffix_map = {
        "dev": " (Dev)",
        "prerelease": " (Prerelease)",
        "unittest": " (UnitTest)",
    }
    plugin_pretty_name += suffix_map.get(build_mode, "")

    print()
    Colors.print(Colors.GREEN, f"✅ Building: {plugin_pretty_name}")

    # --- Generate file/folder names ---
    # remove parens, replace spaces with dashes, and lowercase
    plugin_name = re.sub(r"[\s]+", "-", plugin_pretty_name.lower())
    plugin_name = re.sub(r"[(),:;'\"]", "", plugin_name)
    Colors.print(Colors.GREEN, f"✅ Output file/folder name: {plugin_name}")

    release_name = f"{plugin_name}-{plugin_version}.op"
    plugins_dir = get_plugins_dir()
    build_dest = plugins_dir / plugin_name

    # --- Build Logic ---
    copy_success = True
    if build_mode in ["dev", "prerelease", "unittest"]:
        # Clean and copy files to dev location
        if build_dest.exists():
            shutil.rmtree(build_dest)
        os.makedirs(build_dest, exist_ok=True)

        copied = shutil.copytree(plugin_src_dir, build_dest, dirs_exist_ok=True)
        print_copied(copied)
        shutil.copy2(info_toml_path, build_dest)

        # Modify info.toml in destination
        dest_info_path = build_dest / "info.toml"
        content = dest_info_path.read_text()
        content = re.sub(
            r'^(name\s*=\s*")(.*)(")',
            rf'\1\2{suffix_map[build_mode]}\3',
            content,
            flags=re.MULTILINE,
        )
        define_map = {
            "dev": "DEV",
            "prerelease": "RELEASE",
            "unittest": "UNIT_TEST",
        }
        content = re.sub(
            r"^#__DEFINES__",
            f'defines = ["{define_map[build_mode]}"]',
            content,
            flags=re.MULTILINE,
        )
        dest_info_path.write_text(content)

    elif build_mode == "release":
        # Create a temporary info.toml for release build
        temp_info_path = plugin_src_dir / "info.toml"
        shutil.copy2(info_toml_path, temp_info_path)
        content = temp_info_path.read_text()
        content = re.sub(
            r"^#__DEFINES__", 'defines = ["RELEASE"]', content, flags=re.MULTILINE
        )
        temp_info_path.write_text(content)

        # Build archive
        build_name = f"{plugin_name}-{int(time.time())}.zip"
        # archive_files = [str(p) for p in plugin_src_dir.glob("*")]
        archive_files = [f"./{plugin_src_dir}/*"]
        if license_path.exists():
            archive_files.append(str(license_path))
        if readme_path.exists():
            archive_files.append(str(readme_path))

        run_command(["7z", "a", build_name] + archive_files)
        shutil.copy2(build_name, release_name)
        os.remove(build_name)
        os.remove(temp_info_path)  # Clean up temp file

        Colors.print(Colors.GREEN, f"\n✅ Built plugin as ./{release_name}.")

    # --- Post-Build ---
    print()
    if not copy_success:
        Colors.print(
            Colors.RED,
            "⚠ Error: Could not copy plugin to Openplanet directory.",
        )
        return
    elif build_mode in ["dev", "prerelease", "unittest"]:
        Colors.print(Colors.GREEN, f"✅ Copied files to {build_dest}")
        # Trigger remote build if available
        if shutil.which("tm-remote-build"):
            run_command(
                [
                    "tm-remote-build",
                    "load",
                    "folder",
                    plugin_name,
                    "--host",
                    get_remote_build_ip(),
                    "--port",
                    "30000",
                ],
                check=False,
            )
        else:
            Colors.print(
                Colors.YELLOW,
                "⚠ tm-remote-build not found, skipping remote reload.",
            )
    Colors.print(Colors.GREEN, f"✅ Release file: {release_name}")

    print()
    Colors.print(Colors.GREEN, "✅ Done.")


if __name__ == "__main__":
    main()
