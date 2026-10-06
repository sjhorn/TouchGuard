#!/usr/bin/env python3
"""Adds (or replaces) a release in the Sparkle appcast.

The release notes are the version's section of CHANGELOG.md, turned into
simple HTML. `--signature` is sign_update's output:
    sparkle:edSignature="..." length="..."
"""
import argparse
import html
import re
import sys
from email.utils import formatdate
from xml.etree import ElementTree as ET

SPARKLE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
DC = "http://purl.org/dc/elements/1.1/"
ET.register_namespace("sparkle", SPARKLE)
ET.register_namespace("dc", DC)


def changelog_section(path: str, version: str) -> str:
    text = open(path, encoding="utf-8").read()
    match = re.search(rf"^## \[{re.escape(version)}\][^\n]*\n(.*?)(?=^## |\Z)", text, re.S | re.M)
    if not match:
        sys.exit(f"error: CHANGELOG.md has no '## [{version}]' section")
    return match.group(1).strip()


def inline(text: str) -> str:
    text = html.escape(text, quote=False)
    text = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", text)
    text = re.sub(r"`(.+?)`", r"<code>\1</code>", text)
    return re.sub(r"\[(.+?)\]\((.+?)\)", r'<a href="\2">\1</a>', text)


def markdown_to_html(md: str) -> str:
    out, in_list = [], False
    for line in md.splitlines():
        line = line.rstrip()
        if line.startswith("- "):
            if not in_list:
                out.append("<ul>")
                in_list = True
            out.append(f"<li>{inline(line[2:])}</li>")
            continue
        if in_list:
            out.append("</ul>")
            in_list = False
        if line.startswith("### "):
            out.append(f"<h3>{inline(line[4:])}</h3>")
        elif line:
            out.append(f"<p>{inline(line)}</p>")
    if in_list:
        out.append("</ul>")
    return "\n".join(out)


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--appcast", required=True)
    p.add_argument("--changelog", required=True)
    p.add_argument("--version", required=True)
    p.add_argument("--build", required=True)
    p.add_argument("--url", required=True)
    p.add_argument("--signature", required=True)
    p.add_argument("--min-system", default="14.0")
    args = p.parse_args()

    attrs = dict(re.findall(r'(\S+?)="([^"]*)"', args.signature))
    if "sparkle:edSignature" not in attrs or "length" not in attrs:
        sys.exit(f"error: unexpected sign_update output: {args.signature!r}")

    tree = ET.parse(args.appcast)
    channel = tree.getroot().find("channel")
    for old in channel.findall("item"):
        if old.findtext(f"{{{SPARKLE}}}version") == args.build or \
           old.findtext(f"{{{SPARKLE}}}shortVersionString") == args.version:
            channel.remove(old)

    item = ET.Element("item")
    ET.SubElement(item, "title").text = f"Version {args.version}"
    ET.SubElement(item, "pubDate").text = formatdate(localtime=False, usegmt=True)
    ET.SubElement(item, f"{{{SPARKLE}}}version").text = args.build
    ET.SubElement(item, f"{{{SPARKLE}}}shortVersionString").text = args.version
    ET.SubElement(item, f"{{{SPARKLE}}}minimumSystemVersion").text = args.min_system
    ET.SubElement(item, "description").text = markdown_to_html(
        changelog_section(args.changelog, args.version))
    ET.SubElement(item, "enclosure", {
        "url": args.url,
        "type": "application/octet-stream",
        f"{{{SPARKLE}}}edSignature": attrs["sparkle:edSignature"],
        "length": attrs["length"],
    })

    # Newest first, after the channel's own elements.
    first_item = next((i for i, el in enumerate(channel) if el.tag == "item"), len(channel))
    channel.insert(first_item, item)
    ET.indent(tree, space="  ")
    tree.write(args.appcast, encoding="utf-8", xml_declaration=True)
    print(f"Added {args.version} ({args.build}) to {args.appcast}")


if __name__ == "__main__":
    main()
