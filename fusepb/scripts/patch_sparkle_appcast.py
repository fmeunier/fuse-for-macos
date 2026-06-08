#!/usr/bin/env python3

import argparse
import pathlib
import sys
import xml.etree.ElementTree as ET

SPARKLE_NAMESPACE = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
ET.register_namespace( 'sparkle', SPARKLE_NAMESPACE )


def parse_args():
  parser = argparse.ArgumentParser(
    description='Patch Sparkle appcast release-notes links to use version-based paths.'
  )
  parser.add_argument(
    '--appcast', required=True,
    help='Path to the generated Sparkle appcast XML file.'
  )
  parser.add_argument(
    '--release-notes-url-prefix', required=True,
    help='Base URL prefix for published per-version release notes.'
  )
  return parser.parse_args()


def main():
  args = parse_args()
  appcast_path = pathlib.Path( args.appcast )

  try:
    tree = ET.parse( appcast_path )
  except ( OSError, ET.ParseError ) as error:
    print( f'error: failed to parse {appcast_path}: {error}', file=sys.stderr )
    return 1

  root = tree.getroot()
  item_path = './channel/item'
  version_tag = f'{{{SPARKLE_NAMESPACE}}}shortVersionString'
  fallback_version_tag = f'{{{SPARKLE_NAMESPACE}}}version'
  notes_tag = f'{{{SPARKLE_NAMESPACE}}}releaseNotesLink'

  changed = False
  for item in root.findall( item_path ):
    version_node = item.find( version_tag )
    if version_node is None or not version_node.text:
      version_node = item.find( fallback_version_tag )

    if version_node is None or not version_node.text:
      print( 'error: appcast item is missing both sparkle:shortVersionString and sparkle:version', file=sys.stderr )
      return 1

    notes_node = item.find( notes_tag )
    if notes_node is None:
      continue

    notes_node.text = f'{args.release_notes_url_prefix}{version_node.text}.md'
    changed = True

  if not changed:
    print( f'error: no sparkle:releaseNotesLink elements found in {appcast_path}', file=sys.stderr )
    return 1

  try:
    tree.write( appcast_path, encoding='utf-8', xml_declaration=True )
  except OSError as error:
    print( f'error: failed to write {appcast_path}: {error}', file=sys.stderr )
    return 1

  return 0


if __name__ == '__main__':
  sys.exit( main() )
