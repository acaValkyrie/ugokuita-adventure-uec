# 音声のクレジット

- `running_loop.wav`: 機体の実機の走行音の録音（リポジトリ acaValkyrie/ugokuita-adventure の `audio/動く板　ガッタン.m4a` の 9〜11 秒）から `tools/make_running_loop.py` で作成。製作者本人の録音。
- `bump/bump_a.ogg`, `bump/bump_b.ogg`: 機体の実機の録音（同リポジトリの `audio/動く板　ガッタン３.m4a` の 2.06 秒と 2.68 秒の衝撃音）から `tools/make_bump_sounds.py` で切り出し。製作者本人の録音。
- `grass/rustle*.ogg`: qubodup「20 Rustles of dry leaves」 https://opengameart.org/content/20-rustles-dry-leaves — CC0 1.0 (http://creativecommons.org/publicdomain/zero/1.0/)。`tools/convert_rustles.py` で8種類を選び、モノラル・音量をそろえてOGGに変換。
- `water/splash_*.ogg`: rubberduck「40 CC0 water / splash / slime SFX」 https://opengameart.org/content/40-cc0-water-splash-slime-sfx — CC0 1.0 (http://creativecommons.org/publicdomain/zero/1.0/)。
- `fanfare/fanfare_02.ogg`: Fantasy Musica（Beau Buckley）「Fanfare 02」 https://opengameart.org/content/fanfare-02 — CC-BY-SA 4.0 (http://creativecommons.org/licenses/by-sa/4.0/)。クレジット: Beau Buckley。パワーアップアイテムを取ったときに鳴らす。元の OGG をそのまま使用（改変なし）。
- `bgm/ending2_fanfare_1.mp3`: tcarisland「Fanfare 1」 https://opengameart.org/content/fanfare-1 — CC-BY 4.0 (https://creativecommons.org/licenses/by/4.0/)。クレジット: tcarisland。エンディング2（空を飛べるパワーアップで一定の高さを越えて無重力になったとき）の BGM として用意。元の MP3（ページ上の `Fanfare_2.mp3`）をそのまま使用（改変なし）。
- `bump/rattle_a.wav`〜`bump/rattle_d.wav`: 段差の音に重ねるプラスチック部品のカチャカチャ音。`tools/gen_rattle.gd` でノイズから合成した自作の音。
