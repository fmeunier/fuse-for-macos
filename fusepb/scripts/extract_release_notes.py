#!/usr/bin/env python3

import argparse
import pathlib
import re
import sys


def parse_args():
  parser = argparse.ArgumentParser(
    description='Extract per-version Sparkle release notes from changelog.md.'
  )
  parser.add_argument(
    '--input', required=True,
    help='Path to the source changelog Markdown file.'
  )
  parser.add_argument(
    '--version', required=True,
    help='User-visible release version to extract.'
  )
  parser.add_argument(
    '--output', required=True,
    help='Path to write the extracted Markdown notes.'
  )
  return parser.parse_args()


def main():
  args = parse_args()

  input_path = pathlib.Path( args.input )
  output_path = pathlib.Path( args.output )

  try:
    text = input_path.read_text( encoding='utf-8' )
  except OSError as error:
    print( f'error: failed to read {input_path}: {error}', file=sys.stderr )
    return 1

  heading = f'## What\'s new in Fuse for macOS {args.version}'
  start = text.find( heading )
  if start == -1:
    print(
      f'error: version {args.version} not found in {input_path}',
      file=sys.stderr,
    )
    return 1

  remainder = text[start:]
  match = re.search(
    r'^## What\'s new in Fuse for macOS .+$',
    remainder[ len( heading ): ],
    re.MULTILINE,
  )

  if match is None:
    section = remainder
  else:
    section = remainder[: len( heading ) + match.start() ]

  section = section.strip() + '\n'

  output_path.parent.mkdir( parents=True, exist_ok=True )
  try:
    output_path.write_text( section, encoding='utf-8' )
  except OSError as error:
    print( f'error: failed to write {output_path}: {error}', file=sys.stderr )
    return 1

  return 0


if __name__ == '__main__':
  sys.exit( main() )
