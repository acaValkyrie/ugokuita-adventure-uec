#!/usr/bin/env python3
"""単体PCKの容量とファイルごとのgzip容量を調べる。"""

import argparse
import json
import struct
import sys
import zlib
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path, PurePosixPath


PACK_HEADER_MAGIC = 0x43504447
PACK_DIR_ENCRYPTED = 1
PACK_REL_FILEBASE = 2
PACK_SPARSE_BUNDLE = 4
PACK_FILE_ENCRYPTED = 1
PACK_FILE_REMOVAL = 2
PACK_FILE_DELTA = 4
CHUNK_SIZE = 1024 * 1024
MB = 1_000_000


class PckError(ValueError):
    pass


@dataclass
class Entry:
    path: str
    offset: int
    size: int
    md5: bytes
    flags: int
    gzip_size: int = 0
    source: str = ""


@dataclass
class Header:
    version: int
    engine: tuple
    flags: int
    file_base: int
    directory_offset: int
    file_count: int
    file_size: int


def read_exact(stream, size):
    data = stream.read(size)
    if len(data) != size:
        raise PckError(f"PCKが途中で切れています (offset={stream.tell()})")
    return data


def read_u32(stream):
    return struct.unpack("<I", read_exact(stream, 4))[0]


def read_u64(stream):
    return struct.unpack("<Q", read_exact(stream, 8))[0]


def read_directory(stream):
    stream.seek(0, 2)
    file_size = stream.tell()
    stream.seek(0)
    if read_u32(stream) != PACK_HEADER_MAGIC:
        raise PckError("単体PCKの先頭にGDPCマジックがありません")
    version = read_u32(stream)
    if version not in (2, 3, 4):
        raise PckError(f"未対応のPCK format version: {version} (対応: 2, 3, 4)")
    engine = tuple(read_u32(stream) for _ in range(3))
    flags = read_u32(stream)
    if flags & PACK_DIR_ENCRYPTED:
        raise PckError("暗号化されたPCKディレクトリには対応していません")
    if flags & PACK_SPARSE_BUNDLE:
        raise PckError("外部ファイルを参照するsparse bundleには対応していません")
    if flags & ~(PACK_DIR_ENCRYPTED | PACK_REL_FILEBASE | PACK_SPARSE_BUNDLE):
        raise PckError(f"未対応のPCK flags: 0x{flags:x}")
    # 単体PCKの開始位置は0なので、相対file_baseもそのまま使う。
    file_base = read_u64(stream)
    if version in (3, 4):
        directory_offset = read_u64(stream)
        if directory_offset < stream.tell() or directory_offset > file_size - 4:
            raise PckError(f"不正なdirectory offset: {directory_offset}")
        stream.seek(directory_offset)
    else:
        read_exact(stream, 16 * 4)  # V2の予約領域。
        directory_offset = stream.tell()
    file_count = read_u32(stream)
    if file_count > (file_size - stream.tell()) // 40:
        raise PckError(f"不正なファイル件数: {file_count}")
    entries = []
    for index in range(file_count):
        path_size = read_u32(stream)
        if not path_size or path_size > file_size - stream.tell() - 36:
            raise PckError(f"不正なパス長: entry={index}, length={path_size}")
        # 長さは末尾のNULパディングを含む。追加のalignは不要。
        raw_path = read_exact(stream, path_size).rstrip(b"\0")
        if b"\0" in raw_path:
            raise PckError(f"パス内にNULがあります: entry={index}")
        try:
            path = raw_path.decode("utf-8")
        except UnicodeDecodeError as exc:
            raise PckError(f"パスがUTF-8ではありません: entry={index}") from exc
        offset = file_base + read_u64(stream)
        size = read_u64(stream)
        md5 = read_exact(stream, 16)
        entry_flags = read_u32(stream)
        if entry_flags & ~(PACK_FILE_ENCRYPTED | PACK_FILE_REMOVAL | PACK_FILE_DELTA):
            raise PckError(f"未対応のfile flags: {path} (0x{entry_flags:x})")
        if entry_flags & PACK_FILE_REMOVAL:
            continue  # 削除指定にはペイロードがない。
        if entry_flags & PACK_FILE_ENCRYPTED:
            raise PckError(f"暗号化ファイルはgzip容量を測定できません: {path}")
        if entry_flags & PACK_FILE_DELTA:
            raise PckError(f"差分パッチファイルには対応していません: {path}")
        if offset > file_size or size > file_size - offset:
            raise PckError(f"ファイル範囲がPCK外です: {path} (offset={offset}, size={size})")
        entries.append(Entry(path, offset, size, md5, entry_flags))
    return Header(version, engine, flags, file_base, directory_offset,
                  file_count, file_size), entries


def resource_path(path):
    return path.removeprefix("res://").replace("\\", "/")


def import_sources(project):
    mapping = defaultdict(set)
    if project is None:
        return mapping
    if not project.is_dir():
        raise PckError(f"プロジェクトディレクトリがありません: {project}")
    for metadata in sorted(project.rglob("*.import")):
        section = ""
        source = metadata.relative_to(project).as_posix()[:-len(".import")]
        for line in metadata.read_text(encoding="utf-8-sig").splitlines():
            line = line.strip()
            if line.startswith("[") and line.endswith("]"):
                section = line[1:-1]
                continue
            if section != "remap" or "=" not in line:
                continue
            key, value = (part.strip() for part in line.split("=", 1))
            if key != "path" and not key.startswith("path."):
                continue
            try:
                target = json.loads(value)
            except (ValueError, TypeError) as exc:
                raise PckError(f"不正なremap値: {metadata}: {line}") from exc
            if not isinstance(target, str):
                raise PckError(f"remap先が文字列ではありません: {metadata}: {line}")
            mapping[resource_path(target)].add(source)
    return mapping


def measure_gzip(stream, entry):
    stream.seek(entry.offset)
    compressor = zlib.compressobj(level=6, wbits=31)
    remaining = entry.size
    result = 0
    while remaining:
        chunk = read_exact(stream, min(remaining, CHUNK_SIZE))
        result += len(compressor.compress(chunk))
        remaining -= len(chunk)
    return result + len(compressor.flush())


def folder_category(entry):
    path = resource_path(entry.path)
    if path.startswith(".godot/imported/") and not entry.source:
        return ".godot/imported unknown"
    parts = PurePosixPath(entry.source or path).parts[:-1]
    return "/".join(parts[:2]) or "(root)"


def print_totals(title, totals):
    print(f"\n{title} (gzip MB降順)")
    print(f"{'count':>8} {'size MB':>12} {'gzip MB':>12}  category")
    for category, (count, size, gzip_size) in sorted(
        totals.items(), key=lambda item: (-item[1][2], item[0])
    ):
        print(f"{count:8,d} {size / MB:12.3f} {gzip_size / MB:12.3f}  {category}")


def report(header, entries, top):
    print(f"format version: {header.version}")
    print("engine version: " + ".".join(map(str, header.engine)))
    print(f"number of files: {header.file_count:,} (payload entries: {len(entries):,})")
    print(f"total bytes: {header.file_size:,} (PCK全体)")
    print(f"payload bytes: {sum(entry.size for entry in entries):,}")
    print("MB = 1,000,000 bytes; gzip = ファイル単位のzlib level 6 / gzip形式")
    print("gzip合計は個別圧縮の合計です。PCK全体のgzip容量とは異なります。")
    print(f"\nTop {top} (size MB降順)")
    print(f"{'size MB':>12} {'gzip MB':>12}  path [source]")
    for entry in sorted(entries, key=lambda item: (-item.size, item.path))[:top]:
        source = f" [source: {entry.source}]" if entry.source else ""
        print(f"{entry.size / MB:12.3f} {entry.gzip_size / MB:12.3f}  {entry.path}{source}")
    extensions = defaultdict(lambda: [0, 0, 0])
    folders = defaultdict(lambda: [0, 0, 0])
    for entry in entries:
        extension = PurePosixPath(entry.source or resource_path(entry.path)).suffix.lower() or "(none)"
        for category, table in ((extension, extensions), (folder_category(entry), folders)):
            table[category][0] += 1
            table[category][1] += entry.size
            table[category][2] += entry.gzip_size
    print_totals("拡張子別 (既知のソース、未対応時はPCK内パス)", extensions)
    print_totals("ソースパスの上位2階層フォルダー別", folders)


def positive_int(value):
    result = int(value)
    if result <= 0:
        raise argparse.ArgumentTypeError("1以上を指定してください")
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pck", type=Path, metavar="file.pck")
    parser.add_argument("--top", type=positive_int, default=40)
    parser.add_argument("--project", type=Path, metavar="DIR")
    args = parser.parse_args(argv)
    try:
        sources = import_sources(args.project)
        with args.pck.open("rb") as stream:
            header, entries = read_directory(stream)
            for entry in entries:
                candidates = sources.get(resource_path(entry.path), set())
                if len(candidates) > 1:
                    raise PckError(f"インポート元が複数あり特定できません: {entry.path}")
                if candidates:
                    entry.source = next(iter(candidates))
                entry.gzip_size = measure_gzip(stream, entry)
        report(header, entries, args.top)
    except (OSError, UnicodeError, PckError, zlib.error) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
