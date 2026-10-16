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
uniform vec4 atmosphere_color : source_color = vec4(0.25, 0.5, 1.0, 1.0);
uniform vec4 earth_haze_color : source_color = vec4(0.55, 0.7, 0.9, 1.0);
uniform vec4 earth_color : source_color = vec4(0.05, 0.15, 0.35, 1.0);
uniform vec4 limb_color : source_color = vec4(0.7, 0.85, 1.0, 1.0);
uniform vec4 sun_glow_color : source_color = vec4(1.0, 0.55, 0.2, 1.0);

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
// 宇宙から見た地球。space_amount が 1 のとき地平線が EYEDIR.y = -HORIZON_DIP まで下がる
const float HORIZON_DIP = 0.1;
// 地平線の上の大気の光の強さと、高さに対する減り方
const float ATMOSPHERE_ENERGY = 1.5;
const float ATMOSPHERE_FALLOFF = 0.06;
// 地平線ぎわの明るい縁の強さと幅
const float LIMB_ENERGY = 1.5;
const float LIMB_WIDTH = 0.008;
// 地球の雲の細かさ
const float CLOUD_SCALE = 1.5;

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

// 2D の value noise（hash13 を流用）
float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash13(vec3(i, 1.0));
    float b = hash13(vec3(i + vec2(1.0, 0.0), 1.0));
    float c = hash13(vec3(i + vec2(0.0, 1.0), 1.0));
    float d = hash13(vec3(i + vec2(1.0, 1.0), 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// 4オクターブの fbm
float fbm2(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise2(p);
        p = p * 2.0 + 17.0;
        a *= 0.5;
    }
    return v;
}

// 宇宙の空で、ライト1つ分の太陽を足す。円盤は地平線より上だけ、光の輪は上下どちらにも出す
vec3 add_space_sun(vec3 color, vec3 eyedir, float horizon, vec3 light_dir, vec3 light_color, float light_energy, float light_size) {
    if (eyedir.y >= horizon) {
        color = add_sun(color, eyedir, light_dir, light_color, light_energy, light_size);
    }
    float s = max(dot(eyedir, light_dir), 0.0);
    color += sun_glow_color.rgb * (pow(s, 64.0) * 2.0 + pow(s, 8.0) * 0.3) * light_energy;
    return color;
}

// 昼の空の、太陽を除いた色（ProceduralSkyMaterial と同じ式）。空側と地面側を別々に返す
vec3 day_sky_color(vec3 eyedir) {
    float v_angle = clamp(eyedir.y, -1.0, 1.0);
    return mix(day_top_color.rgb, day_horizon_color.rgb, clamp(pow(1.0 - v_angle, INV_SKY_CURVE), 0.0, 1.0));
}

vec3 day_ground_color(vec3 eyedir) {
    float v_angle = clamp(eyedir.y, -1.0, 1.0);
    return mix(ground_bottom_color.rgb, ground_horizon_color.rgb, clamp(pow(1.0 + v_angle, INV_GROUND_CURVE), 0.0, 1.0));
}

// 宇宙の空の、太陽を除いた色。地平線より下は地球、地平線に大気の光と縁の光、上は黒い宇宙と星
vec3 space_base_color(vec3 eyedir, float horizon, bool cubemap_pass) {
    float e = eyedir.y;
    float h = horizon;
    vec3 col;

    if (e >= h) {
        col = space_top_color.rgb + atmosphere_color.rgb * ATMOSPHERE_ENERGY * exp(-(e - h) / ATMOSPHERE_FALLOFF);
    } else {
        float d = clamp((h - e) / 0.5, 0.0, 1.0);
        vec3 earth = mix(earth_haze_color.rgb, earth_color.rgb, sqrt(d));
        // 雲。下向きの方向を水平面に投影した座標にノイズをかける。反射用の radiance には描かない
        if (!cubemap_pass) {
            vec2 uv = eyedir.xz / max(h - e, 0.02) * CLOUD_SCALE;
            float clouds = smoothstep(0.55, 0.75, fbm2(uv));
            // 地平線のすぐ近くは投影でノイズが細かくなりすぎるので消す
            clouds *= smoothstep(0.0, 0.05, h - e);
            earth = mix(earth, vec3(0.9), clouds * 0.6);
        }
        col = earth;
    }

    // 地平線の縁の光
    col += limb_color.rgb * LIMB_ENERGY * exp(-abs(e - h) / LIMB_WIDTH);
    return col;
}

void sky() {
    float h = -HORIZON_DIP * space_amount;

    // 昼の空。太陽の円盤は空側にだけ描く
    vec3 day_sky = day_sky_color(EYEDIR);
    // 宇宙の空
    vec3 space_col = space_base_color(EYEDIR, h, AT_CUBEMAP_PASS);

    if (LIGHT0_ENABLED) {
        day_sky = add_sun(day_sky, EYEDIR, LIGHT0_DIRECTION, LIGHT0_COLOR, LIGHT0_ENERGY, LIGHT0_SIZE);
        space_col = add_space_sun(space_col, EYEDIR, h, LIGHT0_DIRECTION, LIGHT0_COLOR, LIGHT0_ENERGY, LIGHT0_SIZE);
    }
    if (LIGHT1_ENABLED) {
        day_sky = add_sun(day_sky, EYEDIR, LIGHT1_DIRECTION, LIGHT1_COLOR, LIGHT1_ENERGY, LIGHT1_SIZE);
        space_col = add_space_sun(space_col, EYEDIR, h, LIGHT1_DIRECTION, LIGHT1_COLOR, LIGHT1_ENERGY, LIGHT1_SIZE);
    }
    if (LIGHT2_ENABLED) {
        day_sky = add_sun(day_sky, EYEDIR, LIGHT2_DIRECTION, LIGHT2_COLOR, LIGHT2_ENERGY, LIGHT2_SIZE);
        space_col = add_space_sun(space_col, EYEDIR, h, LIGHT2_DIRECTION, LIGHT2_COLOR, LIGHT2_ENERGY, LIGHT2_SIZE);
    }
    if (LIGHT3_ENABLED) {
        day_sky = add_sun(day_sky, EYEDIR, LIGHT3_DIRECTION, LIGHT3_COLOR, LIGHT3_ENERGY, LIGHT3_SIZE);
        space_col = add_space_sun(space_col, EYEDIR, h, LIGHT3_DIRECTION, LIGHT3_COLOR, LIGHT3_ENERGY, LIGHT3_SIZE);
    }

    vec3 day_col = mix(day_ground_color(EYEDIR), day_sky, step(0.0, EYEDIR.y));

    // 星。地平線より上だけ。大気の光が強い地平線ぎわでは消す。反射用の radiance には描かない
    if (!AT_CUBEMAP_PASS) {
        space_col += vec3(star_brightness(EYEDIR) * star_energy * smoothstep(h + 0.02, h + 0.25, EYEDIR.y));
    }

    COLOR = mix(day_col, space_col, space_amount);
}