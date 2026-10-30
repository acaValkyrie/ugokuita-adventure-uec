# NadeggMini.obj の Top を、なめらかにつながる面ごとに Top・Shell・Eyes へ分ける
# Fusion/FreeCAD から書き出し直したら再実行する。
# 使い方: python -I tools/split_nadegg_obj.py assets/models/NadeggMini.obj
import math
import sys
from collections import defaultdict
from pathlib import Path


EXPECTED_COUNTS = {'Top': 10305, 'Shell': 6793, 'Eyes': 1942}


def split_obj(path):
    data = path.read_bytes()
    lines = data.splitlines(keepends=True)
    objects = [(i, line.split()[1:]) for i, line in enumerate(lines)
               if line.split()[:1] == [b'o']]
    if any(name == [b'Shell'] for _, name in objects):
        print('Shell は既に存在するため変更しません。')
        return
    tops = [i for i, name in objects if name == [b'Top']]
    if len(tops) != 1:
        raise ValueError('Top オブジェクトがちょうど1個必要です。')
    start = tops[0]
    end = next((i for i, _ in objects if i > start), len(lines))
    vertices = []
    faces = []
    face_lines = []
    for i, line in enumerate(lines[:end]):
        fields = line.split()
        if fields[:1] == [b'v']:
            vertices.append(tuple(float(value) for value in fields[1:4]))
        elif i > start and fields[:1] == [b'f']:
            indices = []
            for field in fields[1:]:
                index = int(field.split(b'/')[0])
                index = index - 1 if index > 0 else len(vertices) + index
                if not 0 <= index < len(vertices):
                    raise ValueError('面の頂点番号が範囲外です。')
                indices.append(index)
            if len(indices) < 3:
                raise ValueError('面には3頂点以上が必要です。')
            faces.append(indices)
            face_lines.append(i)

    # 頂点を共有するだけでは結ばず、ちょうど2面が共有する辺だけを使う。
    edges = defaultdict(list)
    normals = []
    for face_index, face in enumerate(faces):
        normal = [0.0, 0.0, 0.0]
        for a, b in zip(face, face[1:] + face[:1]):
            edges[tuple(sorted((a, b)))].append(face_index)
            p, q = vertices[a], vertices[b]
            normal[0] += (p[1] - q[1]) * (p[2] + q[2])
            normal[1] += (p[2] - q[2]) * (p[0] + q[0])
            normal[2] += (p[0] - q[0]) * (p[1] + q[1])
        length = math.sqrt(sum(value * value for value in normal))
        if length == 0:
            raise ValueError('法線を求められない面があります。')
        normals.append(tuple(value / length for value in normal))

    parents = list(range(len(faces)))

    def find(index):
        while parents[index] != index:
            parents[index] = parents[parents[index]]
            index = parents[index]
        return index

    limit = math.cos(math.radians(45.0))
    for adjacent in edges.values():
        if len(adjacent) != 2:
            continue
        a, b = adjacent
        if sum(x * y for x, y in zip(normals[a], normals[b])) > limit:
            parents[find(b)] = find(a)

    components = defaultdict(list)
    for index in range(len(faces)):
        components[find(index)].append(index)
    labels = {}
    for component in components.values():
        points = [vertices[index] for face in component for index in faces[face]]
        zmin = min(point[2] for point in points)
        rmax = max(math.hypot(point[0], point[1]) for point in points)
        if zmin >= 18.4 and rmax <= 15.2:
            label = 'Eyes'
        elif zmin < 13.0:
            label = 'Shell'
        else:
            label = 'Top'
        for index in component:
            labels[index] = label

    groups = {name: [] for name in EXPECTED_COUNTS}
    for index, line_index in enumerate(face_lines):
        groups[labels[index]].append(lines[line_index])
    counts = {name: len(group) for name, group in groups.items()}
    # 別の形状を誤って書き換えないよう、面数を確認してから出力する。
    if counts != EXPECTED_COUNTS:
        raise ValueError(f'面数が想定と異なります: {counts}（想定: {EXPECTED_COUNTS}）')

    eol = next((b'\r\n' if line.endswith(b'\r\n') else b'\n'
                for line in lines if line.endswith(b'\n')), b'\n')
    face_line_set = set(face_lines)
    output = [line for i, line in enumerate(lines[:end]) if i not in face_line_set]
    # 元の Top 見出しの下に Top の面を続け、Shell・Eyes だけ見出しを追加する。
    output.extend(groups['Top'])
    for name in ('Shell', 'Eyes'):
        output.append(b'o ' + name.encode('ascii') + eol)
        output.append(b'usemtl color_727980' + eol)
        output.extend(groups[name])
    output.extend(lines[end:])
    path.write_bytes(b''.join(output))
    print(f'連結成分: {len(components)}、面数: {counts}')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('使い方: python -I tools/split_nadegg_obj.py <NadeggMini.obj>')
    try:
        split_obj(Path(sys.argv[1]))
    except (OSError, ValueError) as error:
        raise SystemExit(str(error))
