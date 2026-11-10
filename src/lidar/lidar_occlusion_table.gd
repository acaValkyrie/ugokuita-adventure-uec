class_name LidarOcclusionTable
extends Resource
# 機体自身にさえぎられる方向の表。tools/bake_lidar_occlusion.gd で作る。

@export var u_bins := 0
@export var v_bins := 0
# v_index * u_bins + u_index の順。1 ならその方向はふさがる。
@export var occluded := PackedByteArray()
