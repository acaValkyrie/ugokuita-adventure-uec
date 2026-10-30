shader_type spatial;
// ED3 の Nadegg の星形の目。見た目の位置と大きさは変えず、前後の判定だけカメラ側へ depth_bias だけ寄せる。
// 自分の頭（板より最大 3cm ほど手前に出る）には隠れず、それより手前の煙や部品とは普通に前後で判定する。
render_mode unshaded, cull_disabled;

uniform sampler2D glint_texture : source_color, filter_linear_mipmap;
// 前後の判定でカメラ側へ寄せる距離 [m]
uniform float depth_bias = 0.04;
// これより薄いところは描かない（星の形に切り抜く）
uniform float alpha_cut = 0.2;

void fragment() {
    vec4 tex = texture(glint_texture, UV);
    ALBEDO = tex.rgb;
    ALPHA = tex.a;
    ALPHA_SCISSOR_THRESHOLD = alpha_cut;
    // VERTEX はカメラから見た位置。カメラ側へ寄せた点の深度を書く
    vec3 biased = VERTEX + normalize(-VERTEX) * depth_bias;
    vec4 clip = PROJECTION_MATRIX * vec4(biased, 1.0);
    float ndc_z = clip.z / clip.w;
    // Compatibility は奥行きが -1〜1 なので 0〜1 の深度に直す。Forward+ / Mobile はそのまま使える
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
    DEPTH = ndc_z * 0.5 + 0.5;
#else
    DEPTH = ndc_z;
#endif
}
