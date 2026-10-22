class_name KeyBindings
extends RefCounted
# キーボードのキーの割り当て。メニューから変えられる操作のキーを、InputMap の上で入れ替えて、設定ファイルに保存・読み込みする。
# すべて static 関数で、オートロードにはしない。ゲームパッドのイベントには触らない。
# キーは physical_keycode（キー配列が違っても同じ位置のキーとして扱うため）で扱う。

# 割り当てを変えられる操作（メニューに並べる順）。menu（Esc）は変えられない
const ACTIONS := [
    "up", "down", "left", "right",
    "view_up", "view_down", "view_left", "view_right",
    "jump", "boost", "drift", "respawn", "map", "interact",
]
# メニューに出す操作の名前
const ACTION_NAMES := {
    "up": "前進",
    "down": "後退",
    "left": "左に曲がる",
    "right": "右に曲がる",
    "view_up": "カメラ 上",
    "view_down": "カメラ 下",
    "view_left": "カメラ 左",
    "view_right": "カメラ 右",
    "jump": "ジャンプ",
    "boost": "ブースト",
    "drift": "ドリフト",
    "respawn": "Recover",
    "map": "マップ",
    "interact": "看板を開く",
}
# 使えないキー（F1〜F12 は is_allowed で範囲として除く）
const DISALLOWED_KEYS := [
    KEY_CTRL, KEY_ALT, KEY_META, KEY_ESCAPE, KEY_TAB, KEY_BACKSPACE,
    KEY_CAPSLOCK, KEY_NUMLOCK, KEY_SCROLLLOCK, KEY_PRINT, KEY_PAUSE, KEY_MENU,
]
# 設定ファイルのセクション名
const SECTION := "keys"

# 初期の割り当て（操作 → physical_keycode）。最初に使うときに InputMap から読む
static var _defaults := {}


# 使えるキーか。Ctrl・Alt・Meta・Esc・Tab・Backspace・F1〜F12・CapsLock・NumLock・ScrollLock・PrintScreen・Pause・Menu は使えない。
# ブラウザのショートカット（Ctrl+W でタブが閉じる等）やページの操作とぶつかるため
static func is_allowed(physical: Key) -> bool:
    if physical == KEY_NONE:
        return false
    if physical >= KEY_F1 and physical <= KEY_F12:
        return false
    return not physical in DISALLOWED_KEYS


# 最初に InputMap から初期の割り当てを覚える（変更が入る前に読むため、どの関数からも最初に呼ぶ）
static func _ensure_defaults() -> void:
    if not _defaults.is_empty():
        return
    for action in ACTIONS:
        _defaults[action] = _read_key(action)


# 操作の今のキー（InputMap の最初の InputEventKey の physical_keycode）。無ければ KEY_NONE
static func _read_key(action: String) -> Key:
    for event in InputMap.action_get_events(action):
        if event is InputEventKey:
            return event.physical_keycode
    return KEY_NONE


# 操作のキーボードのキーを消して、新しいキーを足す（ゲームパッドのイベントは残す）
static func _write_key(action: String, physical: Key) -> void:
    for event in InputMap.action_get_events(action):
        if event is InputEventKey:
            InputMap.action_erase_event(action, event)
    var key := InputEventKey.new()
    key.physical_keycode = physical
    InputMap.action_add_event(action, key)


# 操作の今の割り当て
static func get_key(action: String) -> Key:
    _ensure_defaults()
    return _read_key(action)


# 操作の初期の割り当て
static func get_default_key(action: String) -> Key:
    _ensure_defaults()
    return _defaults[action]


# 操作のキーを変える。同じキーを別の操作が使っていたら、その操作には元のキーを入れて入れ替える
static func set_key(action: String, physical: Key) -> void:
    _ensure_defaults()
    var old := _read_key(action)
    if old == physical:
        return
    for other in ACTIONS:
        if other != action and _read_key(other) == physical:
            _write_key(other, old)
    _write_key(action, physical)


# すべての操作を初期の割り当てに戻す
static func reset_all() -> void:
    _ensure_defaults()
    for action in ACTIONS:
        _write_key(action, _defaults[action])


# すべて初期の割り当てのままか
static func is_default() -> bool:
    _ensure_defaults()
    for action in ACTIONS:
        if _read_key(action) != _defaults[action]:
            return false
    return true


# 設定ファイルに書く。初期と同じものも全部書く
static func save_to(config: ConfigFile) -> void:
    _ensure_defaults()
    for action in ACTIONS:
        config.set_value(SECTION, action, int(_read_key(action)))


# 設定ファイルから読んで適用する。使えないキーや 0 は無視し、同じキーが重なる値は後から読んだ方を無視する
static func load_from(config: ConfigFile) -> void:
    _ensure_defaults()
    if not config.has_section(SECTION):
        return
    var seen := {}
    for action in ACTIONS:
        var value: Variant = config.get_value(SECTION, action, null)
        if typeof(value) != TYPE_INT or value == 0:
            continue
        var physical: Key = value
        if not is_allowed(physical) or seen.has(physical):
            continue
        seen[physical] = true
        set_key(action, physical)


# キーの表示用の名前。今のキー配列でそのキーに書いてある文字を使う（取れなければ Godot のキー名）。
# 矢印は絵の側で矢印を描くので Up・Down・Left・Right にする
static func key_label(physical: Key) -> String:
    match physical:
        KEY_SPACE:
            return "Space"
        KEY_SHIFT:
            return "Shift"
        KEY_ENTER:
            return "Enter"
        KEY_UP:
            return "Up"
        KEY_DOWN:
            return "Down"
        KEY_LEFT:
            return "Left"
        KEY_RIGHT:
            return "Right"
    var label: Key = DisplayServer.keyboard_get_label_from_physical(physical)
    var text := OS.get_keycode_string(label if label != KEY_NONE else physical)
    return text.to_upper() if text.length() == 1 else text
