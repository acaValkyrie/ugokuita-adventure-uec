# キャンパスのGLBにライトマップ用のUV2（2番目のUV）をSmart UV Projectで追加する
# 使い方: blender --background --factory-startup --python tools/add_uv2.py -- <入力.glb> <出力.glb>
import bpy, time, sys, math

# "--" 以降の引数から入出力パスを受け取る
SRC, OUT = sys.argv[sys.argv.index("--") + 1:][:2]

t0 = time.time()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
print("imported in %.1fs, meshes=%d" % (time.time() - t0, len(bpy.data.meshes)))

# mesh -> first object using it
users = {}
for ob in bpy.data.objects:
    if ob.type == 'MESH' and ob.data not in users:
        users[ob.data] = ob

processed = skipped = 0
merged_verts = 0
used = {"lightmap_pack": 0, "smart_project": 0}
failed = []
view_layer = bpy.context.view_layer

for i, me in enumerate(list(bpy.data.meshes)):
    if i % 50 == 0:
        print("progress %d/%d (%.1fs)" % (i, len(bpy.data.meshes), time.time() - t0), flush=True)
    ob = users.get(me)
    if ob is None or len(me.polygons) == 0:
        skipped += 1
        continue
    if len(me.uv_layers) >= 2:
        print("skip (>=2 uv layers):", me.name)
        skipped += 1
        continue
    if len(me.uv_layers) == 0:
        me.uv_layers.new(name="UVMap")
    first = me.uv_layers[0]
    uv2 = me.uv_layers.new(name="UV2")
    me.uv_layers.active = uv2

    for o in bpy.context.selected_objects:
        o.select_set(False)
    ob.select_set(True)
    view_layer.objects.active = ob
    before = len(me.vertices)
    try:
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        # CAD由来のメッシュは同じ平面の三角形でも頂点を共有せず、UV2の島が細かく分かれるため、重なった頂点をまとめる。
        # 法線の折れ目はシャープな辺として残し、陰影は変えない
        bpy.ops.mesh.remove_doubles(threshold=0.0001, use_sharp_edge_from_normals=True)
        bpy.ops.uv.smart_project(angle_limit=math.radians(66), margin_method='SCALED',
                                 island_margin=0.02, area_weight=0.0,
                                 correct_aspect=True, scale_to_bounds=False)
        used["smart_project"] += 1
    except Exception as e:
        failed.append((me.name, str(e)))
        print("FAILED", me.name, e)
    finally:
        if ob.mode != 'OBJECT':
            bpy.ops.object.mode_set(mode='OBJECT')
    merged_verts += before - len(me.vertices)
    me.uv_layers.active = uv2
    first.active_render = True
    uv2.active_render = False
    me.uv_layers.active = first
    processed += 1

for o in bpy.context.selected_objects:
    o.select_set(False)

print("exporting...", flush=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_texcoords=True,
                          export_normals=True, export_materials='EXPORT', export_yup=True,
                          export_apply=False, export_extras=False, export_animations=False)
print("SUMMARY processed=%d skipped=%d used=%s failed=%d merged_verts=%d time=%.1fs" %
      (processed, skipped, used, len(failed), merged_verts, time.time() - t0))
