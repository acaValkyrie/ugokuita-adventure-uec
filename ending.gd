extends CanvasLayer
# エンディングを出す。画面左上にクレジットとスタート地点に戻るボタンを出し、BGMを流す。Reset でステージに戻ったときも閉じる。
# 普段は街の鳥の声を BGM として流し、エンディング中は止める。
# エンディング1: ステージから落ちたとき（集中線が出始めるほど速く落ちているとき）。
# エンディング2: 東3号館の屋上の5倍の高さまで上がったとき。無重力になる（機体の側で is_zero_gravity() を見て漂わせる）。

# この高さ [m] より下で、集中線が出る速さ（最高速度超え）で落ちていたらエンディングにする
const FALL_HEIGHT := -10.0
# 東3号館（高層棟）の屋上の高さ [m]
const E3_ROOF_HEIGHT := 42.5
# この高さ [m] より上に来たら無重力になってエンディング2にする
const ENDING2_HEIGHT := E3_ROOF_HEIGHT * 5.0
const BGM := preload("res://assets/audio/bgm/これにてお開き、また来週！.mp3")
# エンディング2のBGM。Fanfare 1 (tcarisland) CC BY 4.0。クレジットは assets/audio/CREDITS.md
const BGM2 := preload("res://assets/audio/bgm/ending2_fanfare_1.mp3")
# 普段ずっと流す街の鳥の声。VSQ plus+ の効果音。クレジットは assets/audio/CREDITS.md
const AMBIENT := preload("res://assets/audio/bgm/city_bird.ogg")
const FONT := preload("res://assets/fonts/noto_sans_jp_bold_ending.otf")

var _shown := false
# 出しているエンディング（1か2）
var _ending := 1
var _panel: PanelContainer
var _box: VBoxContainer
var _button: Button
var _player: AudioStreamPlayer
# 普段流す街の鳥の声
var _ambient_player: AudioStreamPlayer
# エンディング2だけで出すラベル
var _ending2_labels: Array[Label] = []
var _bgm2: AudioStreamMP3


func _ready() -> void:
    # 操作説明などの表示（layer 10）より上、メニュー（layer 20）より下に描く
    layer = 15
    _panel = PanelContainer.new()
    # 画面中央の機体に被らないよう、左上のメニューボタンの下に置く
    _panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
    _panel.offset_left = 16
    _panel.offset_top = 72
    var style := UiStyle.make_panel_style(false, 12, true)
    style.content_margin_left = 24
    style.content_margin_right = 24
    style.content_margin_top = 18
    style.content_margin_bottom = 18
    _panel.add_theme_stylebox_override("panel", style)
    _panel.visible = false
    add_child(_panel)

    _box = VBoxContainer.new()
    _box.add_theme_constant_override("separation", 8)
    _panel.add_child(_box)

    # タイトルの左に赤い縦帯を置く
    var title_row := HBoxContainer.new()
    title_row.add_theme_constant_override("separation", 12)
    _box.add_child(title_row)
    var accent_bar := ColorRect.new()
    accent_bar.color = UiStyle.ACCENT_COLOR
    accent_bar.custom_minimum_size = Vector2(5, 32)
    accent_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    title_row.add_child(accent_bar)
    title_row.add_child(_make_label("Thank you for Playing!", 30))

    _box.add_child(_make_ending2_label("- ENDING 2 -", 18))
    _box.add_child(_make_label("製作：動く板製作委員会", 18))
    # 音楽のクレジット（CC BY / CC BY-SA の表記。詳しくは assets/audio/CREDITS.md）。Fanfare 1 はエンディング2の曲なので、ネタバレにならないようエンディング2だけで表記する
    _box.add_child(_make_ending2_label("Music: \"Fanfare 1\" by tcarisland (CC BY 4.0)", 13, UiStyle.TEXT_DIM_COLOR))
    _box.add_child(_make_label("Music: \"Fanfare 02\" by Beau Buckley (CC BY-SA 4.0)", 13, UiStyle.TEXT_DIM_COLOR))

    # ボタンは左寄せ。上の文字との間を 4 あける
    var button_margin := MarginContainer.new()
    button_margin.add_theme_constant_override("margin_top", 4)
    button_margin.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    _box.add_child(button_margin)

    _button = Button.new()
    _button.text = "Back to Start"
    UiStyle.make_accent_button_styles(_button)
    _button.add_theme_font_override("font", FONT)
    _button.add_theme_font_size_override("font_size", 17)
    _button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    _button.pressed.connect(_on_back_pressed)
    button_margin.add_child(_button)

    _player = AudioStreamPlayer.new()
    _player.bus = "BGM"
    _player.stream = BGM
    add_child(_player)
    # エンディング2のBGMは1回だけ流す。ファイルにループ設定があっても繰り返さない
    _bgm2 = BGM2.duplicate() as AudioStreamMP3
    _bgm2.loop = false

    # 街の鳥の声はループして流し続ける
    _ambient_player = AudioStreamPlayer.new()
    _ambient_player.bus = "BGM"
    var ambient_stream := AMBIENT.duplicate() as AudioStreamOggVorbis
    ambient_stream.loop = true
    _ambient_player.stream = ambient_stream
    add_child(_ambient_player)
    _ambient_player.play()


func _process(_delta: float) -> void:
    var car := get_tree().get_first_node_in_group("player") as VehicleBody3D
    if car == null:
        return
    var height := car.global_position.y
    if _shown:
        # Back to Start を押さずに Reset でステージに戻ったら閉じる
        if _ending == 1 and height >= FALL_HEIGHT:
            _hide()
        elif _ending == 2 and height <= ENDING2_HEIGHT:
            _hide()
        return
    if height > ENDING2_HEIGHT:
        _show(2)
    # 集中線が出始める条件（最高速度超え）と同じ
    elif height < FALL_HEIGHT and car.linear_velocity.length() > car.get_max_speed():
        _show(1)


func get_button_rect() -> Rect2:
    if not _panel.visible:
        return Rect2()
    return _button.get_global_rect()


# エンディングを出しているか（カメラを機体に寄せるのに使う）
func is_shown() -> bool:
    return _shown


# エンディング2を出しているか（機体を無重力にするのに使う）
func is_zero_gravity() -> bool:
    return _shown and _ending == 2


# エンディング用フォントの縁取りなしのラベル
func _make_label(text: String, size: int, color: Color = UiStyle.TEXT_COLOR) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_override("font", FONT)
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    return label


# エンディング2だけで出すラベル
func _make_ending2_label(text: String, size: int, color: Color = UiStyle.TEXT_COLOR) -> Label:
    var label := _make_label(text, size, color)
    _ending2_labels.append(label)
    return label


func _show(ending: int) -> void:
    _shown = true
    _ending = ending
    for label in _ending2_labels:
        label.visible = ending == 2
    _panel.visible = true
    _ambient_player.stop()
    _player.stream = _bgm2 if ending == 2 else BGM
    _player.play()
    # ゲームパッドやキーボードの決定でも押せるようにする
    _button.grab_focus()


func _hide() -> void:
    _shown = false
    _panel.visible = false
    _player.stop()
    # 街の鳥の声を頭から流し直す（すでに流れているときは何もしない）
    if not _ambient_player.playing:
        _ambient_player.play()
    _button.release_focus()


func _on_back_pressed() -> void:
    _hide()
    get_tree().reload_current_scene()
