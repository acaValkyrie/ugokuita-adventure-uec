# 新倉庫（Gomi Station）の備品画像

学内で不要になった備品を集め、必要な学内の人が持ち帰れる新倉庫の表現に使う。
2026-10-24にCodexのbuilt-in `image_gen`で新規生成した画像。

- `surplus_equipment_atlas.png`: 透明背景のディスプレイ2種・PC2種。`gomi_station_contents.tscn`のAtlasTextureで各品を切り出す。Y軸固定ビルボードにし、アルファ閾値0.5で背景を切り抜く。
- 棚はラックごとに分類する。奥側の白棚と北側の緑ラック3台はディスプレイ44台、前側の緑ラック3台はPC44台、前側の白棚はオシロスコープ6台の専用棚。合計94点を維持している。
- 緑ラックには、元モデルの横桟に揃えた高さ0.60m・1.12m・1.64mの薄い棚板がある。
- `surplus_oscilloscope.png`: 波形画面・操作ノブ・BNC端子が見えるオシロスコープの透明カットアウト。
- `surplus_bin_contents.png`: USBケーブル、キーボード、マウス、スイッチングハブなどが雑多に重なった真上からの画像。中央の水色箱4つの内側に、1.94m×1.14mの水平面として配置。元メッシュの下端0.01m・上端0.73mの中間（0.37m）に置き、隣同士で180度回転させる。内側底板の上面は0.03mなので、収納深さに対しては約48.6%の高さ。

各画像は遠方でのちらつきを抑えるためミップマップを生成する。

2026-10-27、Web 版を軽くするため、`surplus_equipment_atlas.png`（1536×1024 → 768×512）と `surplus_oscilloscope.png`（1774×887 → 887×444）を半分に縮めた。`AtlasTexture` の `region` はこの画像のピクセルの座標なので、画像の大きさを変えるときは `gomi_station_contents.tscn` の `region` と `tools/verify_gomi_contents.gd` のディスプレイとPCを分ける高さのしきい値も合わせて変える。取り込み設定の `size_limit` で縮めると、`region` とずれて品物が切れる。新倉庫の元モデルはZ軸が上なので、配置用シーンのY軸が上の座標系を親ノードで変換している。

## Nadeggの大きさ

`gym.tscn`のNadeggインスタンスは、回転を含む基底の各軸の長さが2。新倉庫もモデル倍率を2に揃え、メッシュの外形寸法が体育館と同じ約0.24m×0.22m×0.24mになるようにしている。衝突球の半径は0.115m、中心高は0.12m。奥の5体の平面上の配置は維持し、床に接する高さに置いている。

## 箱の衝突と入退出検知

4箱のIDは `SouthWest`、`SouthEast`、`NorthWest`、`NorthEast`。中身画像の面（高さ0.37m）の直下に厚さ0.02mのStaticBodyを置き、内壁を越えない1.94m×1.14mの物理面としている。各箱の`Interior` Area3Dは画像面から上端0.73mまでを覆い、衝突レイヤー1のbodyを監視する。車・旧CharacterBody・`player`グループの機体を対象にし、棚やNadeggのStaticBodyは通知から除く。

GomiStationルート（`gomi_station.gd`）から次を使える。重なり状態の照会は物理フレームで更新される。

```gdscript
station.surplus_bin_entered.connect(func(bin_id, body): print("入場: ", bin_id, body))
station.surplus_bin_exited.connect(func(bin_id, body): print("退場: ", bin_id, body))
var occupied_bins = station.get_surplus_bin_ids_for_body(player)
var visitors = station.get_bodies_in_surplus_bin(&"SouthWest")
```

検証は `Godot --path . --script res://tools/verify_gomi_contents.gd`。棚分類、体育館とのNadegg寸法比較、全4箱への実車/旧CharacterBodyの入退出、照会API、落下物を支える物理面を確認する。

## 生成プロンプト

### 棚の備品（透明背景）

```text
Use case: stylized-concept. Asset type: transparent cutout texture atlas for Godot 3D warehouse shelf billboards, campus reuse store. Create exactly 4 separate standalone old office equipment items, arranged 2x2 in equal quadrants on true transparent background, generous transparent gutters. Top left: a black 16:9 LCD computer display with pedestal, front view. Top right: an older beige 4:3 LCD computer display with pedestal, front view. Bottom left: a dark gray small desktop PC tower front view, with visible optical drive and vents. Bottom right: beige compact desktop computer tower, front view. Every item fully within its quadrant, centered and grounded at same baseline in each quadrant. Mostly straight-on elevation, tiny 3/4 depth acceptable. Realistic simplified game prop render matching simple CAD building models, muted gray and beige materials, soft neutral lighting, crisp readable silhouettes. Used but intact surplus university equipment, blank switched-off screens. No floor, no shelf, no backdrop, no cast shadow outside objects, no logos, no labels, no text, no watermark.
```

### 箱の中身

```text
Use case: stylized-concept. Asset type: single albedo texture applied to a flat horizontal surface just inside a light blue 2m by 1.2m university surplus equipment bin in a Godot game. Primary request: straight orthographic overhead view of a dense jumbled pile of reused old office electronics and cables. Contents: many tangled black and gray USB cables with identifiable USB-A plugs, several beige and black full-size keyboards, numerous wired computer mice, two small gray Ethernet switching hubs with RJ45 ports, power adapters and coiled network cables. Used but intact university spare equipment, all tossed together and partially overlapping. The pile completely fills a rectangular 5:3 landscape frame edge to edge. Subtle pale blue bin bottom peeking through tiny gaps only. No visible bin rim or walls, no perspective, no side view, no empty border, no text, no logo, no humans, no water. Style: simplified realistic game prop render, muted charcoal gray, off-white and gray materials, soft diffuse overhead light and subtle contact shadows, readable individual objects and substantial cable clutter. The entire composition must work as one texture seen from above.
```

### オシロスコープ（透明背景）

```text
Use case: stylized-concept. Asset type: single transparent cutout image for a Godot 3D university surplus warehouse shelf billboard. Primary request: one used but intact benchtop digital oscilloscope, straight-on front elevation, fully visible with generous transparent margin. Light gray compact wide rectangular instrument body, a dark display screen on the left showing crisp bright green and cyan oscilloscope waveforms over a subtle square grid, dense but clearly separated physical rotary knobs and square buttons on the right, and four round BNC metal input connectors along the lower front edge with yellow, cyan, magenta, and green channel accents. Small fold-out front feet under the instrument. Readable at small game prop size through clear silhouette, screen, knobs, connectors. Simplified realistic game prop render matching neutral CAD building and office equipment textures. Soft neutral lighting, slightly worn matte gray plastic and brushed metal, minimal depth, frontal view with only a hint of top surface. No extra devices, no cables, no table, no floor, no background, no cast shadow outside object, no logo, no brand, no watermark, no legible text. True transparent background.
```
