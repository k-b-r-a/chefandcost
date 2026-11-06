#!/usr/bin/env python3
"""
Standalone utility to extract and generate an AST-based repository map using
Aider's native RepoMap implementation without running the full interactive CLI.
"""

import argparse
import io
import os
import sys
from pathlib import Path
from unittest.mock import patch

try:
    from aider.io import InputOutput
    from aider.repo import GitRepo
    from aider.repomap import RepoMap
except ImportError as err:
    print(
        f"Error: Required 'aider' dependency not found: {err}\n"
        "Please ensure 'aider-chat' is installed (e.g. pip install aider-chat).",
        file=sys.stderr,
    )
    sys.exit(1)

try:
    from aider.models import Model
except ImportError:
    Model = None

try:
    from aider.waiting import Spinner
except ImportError:
    Spinner = None


def _is_git_repo(path: str) -> bool:
    """Check if the path or any of its parents is a Git repository."""
    cur = os.path.abspath(path)
    while True:
        if os.path.isdir(os.path.join(cur, ".git")):
            return True
        parent = os.path.dirname(cur)
        if parent == cur:
            return False
        cur = parent


def get_repo_map(root_dir: str = ".", max_map_tokens: int = 1024) -> str:
    """
    Extract and generate an AST-based repository map using Aider's native RepoMap.

    Args:
        root_dir: Target directory path within a Git repository (default: ".").
        max_map_tokens: Token budget for the structural AST map (default: 1024).

    Returns:
        Formatted string containing the structural AST signatures and hierarchy.
    """
    root_path = os.path.abspath(root_dir)

    if not os.path.exists(root_path):
        raise ValueError(f"Target directory '{root_path}' does not exist.")

    if not _is_git_repo(root_path):
        raise ValueError(f"Target directory '{root_path}' is not inside a Git repository.")

    # Suppress verbose terminal output and animations from polluting STDOUT
    devnull = io.StringIO()

    # Disable terminal Spinner if available
    spinner_patches = []
    if Spinner is not None:
        spinner_patches.append(patch.object(Spinner, "step", lambda *a, **kw: None))
        spinner_patches.append(patch.object(Spinner, "end", lambda *a, **kw: None))

    for p in spinner_patches:
        p.start()

    try:
        from contextlib import redirect_stdout

        with redirect_stdout(devnull):
            io_handler = InputOutput(yes=True, pretty=False)
            try:
                repo = GitRepo(io_handler, [], root_path)
            except Exception as e:
                raise ValueError(
                    f"Failed to initialize Git repository at '{root_path}': {e}"
                ) from e

            tracked_files = repo.get_tracked_files()
            if not tracked_files:
                return ""

            # Initialize model for token counting
            main_model = Model("gpt-4o") if Model else None
            if main_model is None:
                class FallbackTokenModel:
                    def token_count(self, text: str) -> int:
                        return max(1, len(text) // 4)

                main_model = FallbackTokenModel()

            repo_map = RepoMap(
                map_tokens=max_map_tokens,
                root=root_path,
                main_model=main_model,
                io=io_handler,
                verbose=False,
            )

            result = repo_map.get_repo_map([], tracked_files)
            return result or ""
    finally:
        for p in spinner_patches:
            p.stop()


def main():
    parser = argparse.ArgumentParser(
        description="Generate an AST-based repository map using Aider's native RepoMap implementation."
    )
    parser.add_argument(
        "--target-dir",
        default=".",
        help="Target directory path (default: current working directory).",
    )
    parser.add_argument(
        "-t",
        "--tokens",
        type=int,
        default=1024,
        help="Token budget for the repository map (default: 1024).",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=str,
        default=None,
        help="Optional file path to write output (default: print to STDOUT).",
    )

    args = parser.parse_args()

    try:
        repo_map_content = get_repo_map(
            root_dir=args.target_dir,
            max_map_tokens=args.tokens,
        )
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error generating repo map: {e}", file=sys.stderr)
        sys.exit(1)

    if args.output:
        try:
            output_file = Path(args.output).resolve()
            output_file.parent.mkdir(parents=True, exist_ok=True)
            output_file.write_text(repo_map_content, encoding="utf-8")
            print(f"Repository map written to {output_file}", file=sys.stderr)
        except OSError as e:
            print(f"Error writing to output file '{args.output}': {e}", file=sys.stderr)
            sys.exit(1)
    else:
        if repo_map_content:
            sys.stdout.write(repo_map_content)
            if not repo_map_content.endswith("\n"):
                sys.stdout.write("\n")
            sys.stdout.flush()


if __name__ == "__main__":
    main()
