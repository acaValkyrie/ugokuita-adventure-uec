# 2つのGLBのノードのパス・ワールド座標での範囲・マテリアルが一致するかを比べる（UV2を足す前後の確認用）
# 使い方: python tools/compare_glb.py <A.glb> <B.glb>
import json, struct, sys, math
import numpy as np

def load(path):
    data = open(path, 'rb').read()
    jlen = struct.unpack_from('<I', data, 12)[0]
    j = json.loads(data[20:20 + jlen])
    blen = struct.unpack_from('<I', data, 20 + jlen)[0]
    binbuf = data[28 + jlen:28 + jlen + blen]
    return j, binbuf

def local_matrix(n):
    if 'matrix' in n:
        return np.array(n['matrix'], dtype=float).reshape(4, 4).T
    t = n.get('translation', [0, 0, 0]); r = n.get('rotation', [0, 0, 0, 1]); s = n.get('scale', [1, 1, 1])
    x, y, z, w = r
    R = np.array([[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)],
                  [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)],
                  [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]])
    M = np.eye(4); M[:3, :3] = R * np.array(s); M[:3, 3] = t
    return M

def world_entries(j):
    """(path_name, world_matrix, node) for each node, path = names from root."""
    out = []
    def rec(i, parent_m, path):
        n = j['nodes'][i]
        m = parent_m @ local_matrix(n)
        p = path + '/' + n.get('name', '')
        out.append((p, m, n))
        for c in n.get('children', []):
            rec(c, m, p)
    for r in j['scenes'][j.get('scene', 0)]['nodes']:
        rec(r, np.eye(4), '')
    return out

def world_bounds(j, node, m):
    if 'mesh' not in node:
        return None
    lo = np.full(3, np.inf); hi = np.full(3, -np.inf); mats = []
    for p in j['meshes'][node['mesh']]['primitives']:
        acc = j['accessors'][p['attributes']['POSITION']]
        mn, mx = np.array(acc['min']), np.array(acc['max'])
        corners = np.array([[a, b, c, 1] for a in (mn[0], mx[0]) for b in (mn[1], mx[1]) for c in (mn[2], mx[2])])
        w = (m @ corners.T).T[:, :3]
        lo = np.minimum(lo, w.min(0)); hi = np.maximum(hi, w.max(0))
        mats.append(j['materials'][p['material']]['name'] if 'material' in p else None)
    return lo, hi, sorted(mats, key=str)

a, _ = load(sys.argv[1]); o, _ = load(sys.argv[2])
ea = world_entries(a); eo = world_entries(o)
from collections import defaultdict
ga = defaultdict(list); go = defaultdict(list)
for p, m, n in ea: ga[p].append((m, n))
for p, m, n in eo: go[p].append((m, n))
print('paths a', len(ga), 'o', len(go), 'only_a', len(set(ga) - set(go)), 'only_o', len(set(go) - set(ga)))
bad_bounds = 0; bad_mats = 0; checked = 0; ex = []
for p in ga:
    if p not in go or len(ga[p]) != len(go[p]):
        continue
    for (ma, na), (mo, no) in zip(ga[p], go[p]):
        ba = world_bounds(a, na, ma); bo = world_bounds(o, no, mo)
        if ba is None and bo is None:
            continue
        checked += 1
        if ba is None or bo is None:
            bad_bounds += 1; continue
        d = max(np.abs(ba[0] - bo[0]).max(), np.abs(ba[1] - bo[1]).max())
        if d > 0.01:
            bad_bounds += 1
            if len(ex) < 5: ex.append((p, round(float(d), 3)))
        if ba[2] != bo[2]:
            bad_mats += 1
print('mesh nodes checked', checked, 'bounds_diff>1cm', bad_bounds, 'material_diff', bad_mats)
for e in ex: print('  ex', e)
