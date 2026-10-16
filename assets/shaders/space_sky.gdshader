shader_type sky;
render_mode use_debanding;
// 昼の空（ProceduralSkyMaterial と同じ式）と、高さに応じて混ぜる宇宙の空。space_amount が 0 で昼、1 で宇宙

// 昼の空の色
uniform vec4 day_top_color : source_color = vec4(0.56, 0.7, 0.84, 1.0);
uniform vec4 day_horizon_color : source_color = vec4(0.9, 0.88, 0.8, 1.0);
uniform vec4 ground_bottom_color : source_color = vec4(0.45, 0.43, 0.4, 1.0);
uniform vec4 ground_horizon_color : source_color = vec4(0.9, 0.88, 0.8, 1.0);

// 宇宙の空の色
uniform vec4 space_top_color : source_color = vec4(0.0, 0.0, 0.02, 1.0);
uniform vec4 space_horizon_color : source_color = vec4(0.04, 0.06, 0.14, 1.0);
uniform vec4 space_ground_color : source_color = vec4(0.02, 0.02, 0.04, 1.0);

// 0 で昼の空、1 で宇宙
uniform float space_amount : hint_range(0, 1) = 0.0;
// 星の明るさ。トーンマップの露出で暗くならないよう強めにしてある
uniform float star_energy = 4.0;

// ProceduralSkyMaterial の既定値（sky_curve 0.15、ground_curve 0.02、sun_angle_max 30度、sun_curve 0.15）から求めた値
const float INV_SKY_CURVE = 4.0;
const float INV_GROUND_CURVE = 30.0;
// cos(30度)
const float SUN_ANGLE_MAX = 0.8660254;
const float INV_SUN_CURVE = 22.78;
// 星を置く格子の細かさ（単位ベクトルに掛ける）
const float STAR_GRID = 300.0;
// 星が置かれるセルの割合
const float STAR_RATE = 0.003;

float hash13(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.zyx + 31.32);
    return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.xxy + p.yxx) * p.zyx);
}

// ProceduralSkyMaterial と同じ式で、ライト1つ分の太陽の円盤を color に重ねる
vec3 add_sun(vec3 color, vec3 eyedir, vec3 light_dir, vec3 light_color, float light_energy, float light_size) {
    float sun_angle = dot(light_dir, eyedir);
    float sun_size = cos(light_size);
    if (sun_angle > sun_size) {
        return light_color * light_energy;
    } else if (sun_angle > SUN_ANGLE_MAX) {
        float c2 = (sun_size - sun_angle) / (sun_size - SUN_ANGLE_MAX);
        return mix(color, light_color * light_energy, clamp(pow(1.0 - c2, INV_SUN_CURVE), 0.0, 1.0));
    }
    return color;
}

// 星の明るさ（0〜1）。方向を格子のセルに分け、一部のセルにだけ小さな点を置く
float star_brightness(vec3 eyedir) {
    vec3 p = normalize(eyedir) * STAR_GRID;
    vec3 cell = floor(p);
    if (hash13(cell) > STAR_RATE) {
        return 0.0;
    }
    vec3 star_pos = cell + 0.2 + 0.6 * hash33(cell);
    float d = length(p - star_pos);
    float dot_alpha = smoothstep(0.6, 0.0, d);
    float bright = mix(0.3, 1.0, hash13(cell + 17.0));
    return dot_alpha * bright;
}

void sky() {
    // ProceduralSkyMaterial の空と地面
    float v_angle = clamp(EYEDIR.y, -1.0, 1.0);

    vec3 sky_top = mix(day_top_color.rgb, space_top_color.rgb, space_amount);
    vec3 sky_horizon = mix(day_horizon_color.rgb, space_horizon_color.rgb, space_amount);
    vec3 sky_color = mix(sky_top, sky_horizon, clamp(pow(1.0 - v_angle, INV_SKY_CURVE), 0.0, 1.0));

    vec3 ground_bottom = mix(ground_bottom_color.rgb, space_ground_color.rgb, space_amount);
    vec3 ground_horizon = mix(ground_horizon_color.rgb, space_horizon_color.rgb, space_amount);
    vec3 ground_color = mix(ground_bottom, ground_horizon, clamp(pow(1.0 + v_angle, INV_GROUND_CURVE), 0.0, 1.0));

    // 太陽の円盤（宇宙でも残す）。空側にだけ描く
    vec3 col = sky_color;
    if (LIGHT0_ENABLED) {
        col = add_sun(col, EYEDIR, LIGHT0_DIRECTION, LIGHT0_COLOR, LIGHT0_ENERGY, LIGHT0_SIZE);
    }
    if (LIGHT1_ENABLED) {
        col = add_sun(col, EYEDIR, LIGHT1_DIRECTION, LIGHT1_COLOR, LIGHT1_ENERGY, LIGHT1_SIZE);
    }
    if (LIGHT2_ENABLED) {
        col = add_sun(col, EYEDIR, LIGHT2_DIRECTION, LIGHT2_COLOR, LIGHT2_ENERGY, LIGHT2_SIZE);
    }
    if (LIGHT3_ENABLED) {
        col = add_sun(col, EYEDIR, LIGHT3_DIRECTION, LIGHT3_COLOR, LIGHT3_ENERGY, LIGHT3_SIZE);
    }

    col = mix(ground_color, col, step(0.0, EYEDIR.y));

    // 星。地平線より下にも出す。反射用の radiance には描かない
    if (!AT_CUBEMAP_PASS && space_amount > 0.0) {
        col += vec3(star_brightness(EYEDIR) * star_energy * space_amount);
    }

    COLOR = col;
}
