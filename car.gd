extends VehicleBody3D

const JetExhaustScript := preload("res://jet_exhaust.gd")
const DriftSparksScript := preload("res://drift_sparks.gd")

@export var MAX_STEER = 0.5
# 最高速度で走っているときのハンドルの最大角 [rad]。速いほど MAX_STEER からこの値へ絞り、高速で切ったときにスピンしないようにする
@export var MAX_STEER_AT_SPEED = 0.15
@export var ENGINE_POWER = 80.0
@export var MAX_SPEED = 6.0
@export var BRAKE_FORCE = 1.0
# 走行音のピッチ（停止時〜最高速度）
@export var RUN_SOUND_MIN_PITCH := 0.8
@export var RUN_SOUND_MAX_PITCH := 1.4
# 走行音の音量の追従の速さ [1/s]
@export var RUN_SOUND_FADE := 6.0
# モーター（後輪の外周）の速さの変化の速さ [m/s²]
@export var MOTOR_ACCEL = 12.0
# ブースト中のモーターの速さ（MAX_SPEED に対する倍率）
@export var BOOST_MOTOR_RATIO := 1.6
# ブースト中にモーターの速さを変える速さ [m/s²]（普段の MOTOR_ACCEL より速く唸らせる）
@export var BOOST_MOTOR_ACCEL := 40.0
# ブースト中、モーターの速さが BOOST_MOTOR_RATIO に達したときの走行音のピッチ
@export var RUN_SOUND_BOOST_PITCH := 1.8
# ジャンプの初速 [m/s]
@export var JUMP_SPEED = 4.0
# ブーストの加速度 [m/s²] と、かける時間 [s]
@export var BOOST_ACCEL = 20.0
@export var BOOST_DURATION = 0.4
# ブーストのゲージが満タンになるまでに走る距離 [m]
@export var BOOST_CHARGE_DISTANCE = 40.0
# 激突の音: 1回の物理フレームでの水平速度の変化 [m/s]。これ以上で激突とみなす
@export var CRASH_MIN_DV := 2.5
# この変化で最大音量
@export var CRASH_FULL_DV := 6.0
# 続けて鳴らさない時間 [s]
@export var CRASH_COOLDOWN := 0.4
# 激突の音の全体の音量 [dB]（強さに応じた音量にこの値を足す）
@export var CRASH_VOLUME_DB := 14.0
# 1回の物理更新で進む距離がこれ未満なら、通り道を先に調べない [m]（当たり判定の半分の厚さより小さければ、物理エンジンだけですり抜けないため）
@export var SWEEP_MIN_DISTANCE := 0.04
# 面の手前に残す余裕 [m]。ちょうど面で止めると、その後の重力などで少しめり込み、傾いたときに抜けるため。最後の数cmは物理エンジンに任せる
@export var SWEEP_MARGIN := 0.03
# すり抜け防止が働いてから、フレームごとの水平の速度変化を足し合わせる時間 [s]。ぶつかる直前の数フレームに分けて速度が落ちるので、激突の判定ではこの間の合計も見る
@export var SWEEP_CRASH_WINDOW := 0.1
# ジェットの上向きの加速度 [m/s²]（重力を打ち消したうえで足す分）
@export var JET_LIFT_ACCEL := 14.0
# ジェットで上がる速さの上限 [m/s]
@export var JET_MAX_RISE_SPEED := 6.0
# 空中で水平の速さを目標に近づける加速度 [m/s²]
@export var JET_AIR_ACCEL := 8.0
# 空中でハンドルを切ったときの向きの変わる速さ [rad/s]
@export var JET_TURN_SPEED := 2.0
# 空中で機体を水平に戻す強さ [1/s]
@export var JET_UPRIGHT_GAIN := 4.0
# ドリフトに入れる前向きの速さの下限 [m/s]
@export var DRIFT_MIN_SPEED := 3.0
# 水平の速さがこれ未満になるとドリフトが終わる [m/s]
@export var DRIFT_END_SPEED := 2.0
# ドリフトに入るのに必要なハンドルの入力の大きさ
@export var DRIFT_START_STEER := 0.3
# ドリフト中に向きが変わる速さ [rad/s]（スティックが中央のとき）
@export var DRIFT_YAW_RATE := 2.2
# 曲がる向きにスティックを倒し切ったときの向きの変わる速さ [rad/s]
@export var DRIFT_YAW_TIGHT := 3.2
# 逆向きに倒し切ったときの向きの変わる速さ [rad/s]
@export var DRIFT_YAW_WIDE := 1.2
# 進む向きを機体の向きへ近づける速さ [1/s]（小さいほど横に滑る）
@export var DRIFT_GRIP := 5.0
# ドリフト中の全輪の wheel_friction_slip
@export var DRIFT_FRICTION_SLIP := 0.4
# ドリフト中に前輪を逆に切る角度 [rad]（見た目用）
@export var DRIFT_COUNTER_STEER := 0.2
# 段差などで浮いても、ドリフトを続ける時間 [s]
@export var DRIFT_AIR_GRACE := 0.3
# 1段目（青い火花）になるまでのドリフトの時間 [s]
@export var DRIFT_STAGE1_TIME := 1.0
# 2段目（オレンジの火花）になるまでの時間 [s]
@export var DRIFT_STAGE2_TIME := 2.2
# ドリフトのダッシュの加速度 [m/s²]
@export var DRIFT_TURBO_ACCEL := 25.0
# 1段目で離したときのダッシュの時間 [s]
@export var DRIFT_TURBO_TIME1 := 0.25
# 2段目で離したときのダッシュの時間 [s]
@export var DRIFT_TURBO_TIME2 := 0.5
# ドリフト中のチャージの音の音量 [dB]
@export var DRIFT_CHARGE_VOLUME_DB := 12.0
# ドリフトのダッシュの音の音量 [dB]
@export var DRIFT_DASH_VOLUME_DB := 6.0
# このプレイヤーの機体（MODELS のキー。GameMenu.ROBOT_MODELS と同じ値）
@export var robot_key: String = "neo"
# サスペンションが無い機体として、見た目のタイヤを上下させない（物理のホイールの上下は無視し、回転とステアリングだけ反映する）
@export var rigid_visual_wheels := false

var _run_sound: AudioStreamPlayer3D
var _run_volume := 0.0
# 後輪の外周の速さ [m/s]、前進が正
var _motor_speed := 0.0
# ブーストのゲージ（0〜1、1で発動できる）
var boost_gauge := 0.0
# ブーストの残り時間 [s] と向き（前が1、後ろが-1）
var _boost_time := 0.0
var _boost_dir := 1.0
# 空中でのジャンプ（二段ジャンプ）を使ったか。接地すると戻る
var _air_jump_used := false
# 無重力（エンディング2）の最初のフレームを済ませたか
var _zero_gravity := false
# ジャンプと激突の効果音
# 実機を録音したガッタン音。ジャンプと激突で鳴らす
const BUMP_SOUNDS: Array[AudioStream] = [
    preload("res://assets/audio/bump/bump_a.ogg"),
    preload("res://assets/audio/bump/bump_b.ogg"),
]
var _jump_sound: AudioStreamPlayer3D
# ドリフトの音。チャージはドリフト中に鳴らし、発射はダッシュが出たときに鳴らす
const DRIFT_CHARGE_SOUND := preload("res://assets/audio/drift/drift_charge.ogg")
const DRIFT_DASH_SOUND := preload("res://assets/audio/drift/drift_dash.ogg")
# チャージの音のループの開始位置 [s]。tools/make_drift_sounds.py と合わせる
const CHARGE_LOOP_START := 2.9
var _drift_charge_sound: AudioStreamPlayer3D
var _drift_dash_sound: AudioStreamPlayer3D
var _crash_sound: AudioStreamPlayer
# 前の物理フレームの速度（激突の判定用。リスポーンや機体の入れ替えのときは外から書き換える）
var _prev_velocity := Vector3.ZERO
var _crash_cooldown := 0.0
# すり抜け防止が働いてからの、フレームごとの水平の速度変化の合計 [m/s] と、合計を続ける残り時間 [s]
var _sweep_dv_sum := 0.0
var _sweep_dv_timer := 0.0
# 激突の音を鳴らした回数（テスト用）
var crash_count := 0
# ジェットで上向きの力を出しているか（噴射の見た目に使う）
var jet_thrusting := false
# ドリフト中か、火花の色の段階（0〜2）。火花のスクリプトが読む
var drifting := false
var drift_stage := 0
# ドリフトする向き（左が1、右が-1。Input.get_axis("right", "left") と同じ符号）
var _drift_dir := 0.0
# ドリフトを続けた時間 [s]（地面にいる間だけ進む）と、浮いている時間 [s]
var _drift_time := 0.0
var _drift_air_time := 0.0
# ドリフトに入ったときの水平の速さ [m/s]。アクセル中はこれを下回らないようにする
var _drift_speed := 0.0
# ドリフトのダッシュの残り時間 [s]
var _turbo_time := 0.0
# VehicleWheel3D -> 元の wheel_friction_slip（ドリフトの後で戻す）
var _wheel_friction := {}

func _physics_process(delta: float) -> void:
    # 上向きの力をかけたフレームだけ true にする（エンディング2で return する場合も含め、毎フレーム戻す）
    jet_thrusting = false
    # エンディング2は無重力でふわふわ漂い、操作を受け付けない（機体の入れ替えでも続くよう毎フレーム設定する）
    if Ending.is_zero_gravity():
        cancel_drift()
        gravity_scale = 0.0
        if not _zero_gravity:
            _zero_gravity = true
            # 最初だけ、ゆっくり上へ漂いながら回る
            linear_velocity = Vector3(0.0, 0.5, 0.0)
            angular_velocity = Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
        engine_force = 0.0
        brake = 0.0
        _check_crash(delta)
        _prev_velocity = linear_velocity
        _prevent_tunneling(delta)
        return
    gravity_scale = 1.0
    _zero_gravity = false

    var forward_speed = linear_velocity.dot(global_basis.z)
    # 速いほどハンドルの最大角を絞る
    var steer_limit = lerpf(MAX_STEER, MAX_STEER_AT_SPEED, clampf(absf(forward_speed) / get_max_speed(), 0.0, 1.0))
    var steer_input := Input.get_axis("right", "left")
    var on_ground := _is_on_ground()
    _update_drift(delta, steer_input, forward_speed, on_ground)
    if drifting:
        # ドリフト中は前輪を逆に切る（見た目用）
        steering = move_toward(steering, -_drift_dir * DRIFT_COUNTER_STEER, delta * 10)
    else:
        steering = move_toward(steering, steer_input * steer_limit, delta * 10)

    var throttle = Input.get_axis("down", "up")
    # 最高速度に近づくほど推力を絞る（減速方向の入力は絞らない）
    var limit = clampf(1.0 - absf(forward_speed) / get_max_speed(), 0.0, 1.0)
    if throttle * forward_speed < 0.0:
        limit = 1.0
    engine_force = throttle * _engine_power() * limit
    # 入力がないときはブレーキをかけて坂でずり落ちないようにする
    brake = BRAKE_FORCE if is_zero_approx(throttle) else 0.0

    # 接地して走った水平距離でゲージを貯める（ブースト中は貯めない）
    if _boost_time <= 0.0 and _is_on_ground():
        var horizontal := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
        var charge: float = horizontal.length() * delta / BOOST_CHARGE_DISTANCE
        if PowerUps.has("boost_charge"):
            charge *= PowerUps.BOOST_CHARGE_MULTIPLIER
        boost_gauge = minf(boost_gauge + charge, 1.0)
    # 満タンのときだけ発動できる。後退の入力中なら後ろ向き、それ以外は前向き
    # （発動したフレームからモーターに効かせるため、モーターの処理より前に置く）
    if Input.is_action_just_pressed("boost") and not GameMenu.is_just_closed() \
            and not PowerUps.is_just_closed() and not Map.is_just_closed() \
            and boost_gauge >= 1.0:
        boost_gauge = 0.0
        _boost_time = BOOST_DURATION
        # ブーストを優先し、後ろ向きのブーストとダッシュが同時にかからないようにする
        _turbo_time = 0.0
        _drift_dash_sound.stop()
        _boost_dir = -1.0 if throttle < 0.0 else 1.0

    # アクセル中はモーターの指令に、離したら実際の回転に合わせる（乗り上げて空転しても回り、音も鳴るようにする）
    var wheel_bl := get_node_or_null("VehicleWheel3D_BL") as VehicleWheel3D
    var wheel_br := get_node_or_null("VehicleWheel3D_BR") as VehicleWheel3D
    if wheel_bl != null and wheel_br != null:
        var rpm := (wheel_bl.get_rpm() + wheel_br.get_rpm()) * 0.5
        var measured := rpm / 60.0 * TAU * wheel_bl.wheel_radius
        # 機体が固定されているときなどに回転数がNaNになることがあるので、そのときは0として扱う
        # スリープ中は止まる直前の速度が残って回転数が0にならないので、これも0として扱う
        if is_nan(measured) or sleeping:
            measured = 0.0
        var target := measured
        if not is_zero_approx(throttle):
            target = throttle * get_max_speed()
        var accel: float = MOTOR_ACCEL
        # ブースト中は最高速度より速く、素早く回して唸らせる
        if _boost_time > 0.0:
            target = _boost_dir * get_max_speed() * BOOST_MOTOR_RATIO
            accel = BOOST_MOTOR_ACCEL
        elif _turbo_time > 0.0:
            # ドリフトのダッシュは前向き
            target = get_max_speed() * BOOST_MOTOR_RATIO
            accel = BOOST_MOTOR_ACCEL
        _motor_speed = move_toward(_motor_speed, target, accel * delta)

    # 車輪がどれか接地しているときだけジャンプできる（メニューやポップアップを閉じたボタンでは発動しない）
    # Xbox 表記では看板を開くボタンがジャンプと同じ下のボタンなので、看板の近くでは開くほうを優先する
    # 二段ジャンプを取っていれば、空中でも1回だけもう一度ジャンプできる
    if on_ground:
        _air_jump_used = false
    if Input.is_action_just_pressed("jump") and not GameMenu.is_just_closed() \
            and not PowerUps.is_just_closed() and not Map.is_just_closed() \
            and not (LinkBoard.is_player_near() and Input.is_action_just_pressed("interact")):
        if on_ground:
            apply_central_impulse(Vector3.UP * _jump_speed() * mass)
            _play_jump_sound()
        elif PowerUps.has("double_jump") and not _air_jump_used:
            # 上向きの速度を置き換える（落下中でも同じ高さまで跳ぶ）
            linear_velocity.y = _jump_speed()
            _air_jump_used = true
            _play_jump_sound()

    if _boost_time > 0.0:
        apply_central_force(global_basis.z * _boost_dir * BOOST_ACCEL * mass)
        _boost_time -= delta

    if _turbo_time > 0.0:
        apply_central_force(global_basis.z * DRIFT_TURBO_ACCEL * mass)
        _turbo_time -= delta

    if PowerUps.has("jet"):
        _apply_jet(delta, throttle, on_ground)

    _check_crash(delta)
    # 激突の判定は物理エンジンが出した速度どうしで比べたいので、速度を調整する前に記録する
    _prev_velocity = linear_velocity
    _prevent_tunneling(delta)

# ドリフト。ボタンを押しながらハンドルを切ると始まり、機体を回しながら横に滑る。
# 長く続けるほど火花の段階が上がり、ボタンを離すと段階に応じたダッシュが出る
func _update_drift(delta: float, steer_input: float, forward_speed: float, on_ground: bool) -> void:
    if not drifting:
        # メニューやポップアップを閉じたボタンでは始まらない
        if Input.is_action_pressed("drift") and not GameMenu.is_just_closed() \
                and not PowerUps.is_just_closed() and not Map.is_just_closed() \
                and on_ground and forward_speed >= DRIFT_MIN_SPEED \
                and absf(steer_input) >= DRIFT_START_STEER:
            _drift_dir = signf(steer_input)
            _drift_time = 0.0
            _drift_air_time = 0.0
            _drift_speed = minf(Vector2(linear_velocity.x, linear_velocity.z).length(), get_max_speed())
            drift_stage = 0
            drifting = true
            _drift_charge_sound.play()
            for wheel in _wheel_friction:
                wheel.wheel_friction_slip = DRIFT_FRICTION_SLIP
        return
    if on_ground:
        _drift_time += delta
        _drift_air_time = 0.0
    else:
        _drift_air_time += delta
    if _drift_time >= DRIFT_STAGE2_TIME:
        drift_stage = 2
    elif _drift_time >= DRIFT_STAGE1_TIME:
        drift_stage = 1
    else:
        drift_stage = 0
    var horizontal := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
    if not Input.is_action_pressed("drift"):
        _end_drift(true)
        return
    if _drift_air_time > DRIFT_AIR_GRACE or horizontal.length() < DRIFT_END_SPEED:
        _end_drift(false)
        return
    # スティックを曲がる向きに倒すほど速く、逆に倒すほどゆっくり向きが変わる
    var rel := steer_input * _drift_dir
    var yaw_rate := lerpf(DRIFT_YAW_RATE, DRIFT_YAW_TIGHT, rel) if rel >= 0.0 else lerpf(DRIFT_YAW_RATE, DRIFT_YAW_WIDE, -rel)
    angular_velocity.y = _drift_dir * yaw_rate
    # 進む向きを機体の前向きへ少しずつ回す（速さは保つ）
    var forward_flat := global_basis.z
    forward_flat.y = 0.0
    if forward_flat.is_zero_approx():
        return
    forward_flat = forward_flat.normalized()
    var angle := horizontal.signed_angle_to(forward_flat, Vector3.UP)
    horizontal = horizontal.rotated(Vector3.UP, angle * (1.0 - exp(-DRIFT_GRIP * delta)))
    # タイヤの横の摩擦で失う速さを補い、アクセル中は速さを保つ（向きはそのままで大きさだけ戻す）
    if Input.get_axis("down", "up") > 0.0 and not horizontal.is_zero_approx():
        horizontal = horizontal.normalized() * maxf(horizontal.length(), _drift_speed)
    # linear_velocity を毎フレーム直接書き換えるとサスペンションが効かなくなって車体が沈むので、差を力積で与える
    apply_central_impulse((horizontal - Vector3(linear_velocity.x, 0.0, linear_velocity.z)) * mass)


# ドリフトとダッシュを打ち切る。リスポーンやエンディングで使う
func cancel_drift() -> void:
    if drifting:
        _end_drift(false)
    _turbo_time = 0.0
    _drift_dash_sound.stop()


# ドリフトを終える。release が true（ボタンを離した）で接地しているときだけ、段階に応じたダッシュが出る
func _end_drift(release: bool) -> void:
    for wheel in _wheel_friction:
        wheel.wheel_friction_slip = _wheel_friction[wheel]
    drifting = false
    _drift_charge_sound.stop()
    if release and _is_on_ground():
        if drift_stage == 2:
            _turbo_time = DRIFT_TURBO_TIME2
            _drift_dash_sound.play()
        elif drift_stage == 1:
            _turbo_time = DRIFT_TURBO_TIME1
            _drift_dash_sound.play()
    drift_stage = 0


# ジェット。ジャンプを押している間は上へ押し上げ、空中ではアクセルとハンドルで水平に動かす
func _apply_jet(delta: float, throttle: float, on_ground: bool) -> void:
    var gravity := get_gravity()
    if Input.is_action_pressed("jump") and not GameMenu.is_just_closed() \
            and not PowerUps.is_just_closed() and not Map.is_just_closed() \
            and not gravity.is_zero_approx():
        # 上がる速さが上限に達したら、重力を打ち消すだけにする
        var lift := 0.0 if linear_velocity.y >= JET_MAX_RISE_SPEED else JET_LIFT_ACCEL
        apply_central_force(-gravity * mass + Vector3.UP * mass * lift)
        jet_thrusting = true
    if on_ground:
        return
    # ブースト中やダッシュ中は水平の速度をいじらない（打ち消さないため）
    if _boost_time <= 0.0 and _turbo_time <= 0.0:
        var forward_flat := global_basis.z
        forward_flat.y = 0.0
        forward_flat = forward_flat.normalized()
        var target := forward_flat * throttle * get_max_speed()
        var horizontal := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
        horizontal = horizontal.move_toward(target, JET_AIR_ACCEL * delta)
        linear_velocity = Vector3(horizontal.x, linear_velocity.y, horizontal.z)
    # 機体を水平に保ちつつ、ハンドルで向きを変える
    angular_velocity = global_basis.y.cross(Vector3.UP) * JET_UPRIGHT_GAIN \
            + Vector3.UP * Input.get_axis("right", "left") * JET_TURN_SPEED

# 1回の更新で当たり判定の厚さより大きく進むと、厚みのない地面や壁を通り越してしまう。
# そこで通り道を先に調べ、面の手前で止まる速さに落とす（ぶつかった後の反応は物理エンジンに任せる）
func _prevent_tunneling(delta: float) -> void:
    if sleeping or freeze:
        return
    var motion := linear_velocity * delta
    if motion.length() < SWEEP_MIN_DISTANCE:
        return
    var col: CollisionShape3D = null
    for child in get_children():
        var c := child as CollisionShape3D
        if c != null and c.shape is BoxShape3D:
            col = c
            break
    if col == null:
        return
    var params := PhysicsShapeQueryParameters3D.new()
    params.shape = col.shape
    params.transform = col.global_transform
    params.motion = motion
    params.exclude = [get_rid()]
    params.collision_mask = collision_mask
    var space := get_world_3d().direct_space_state
    var result := space.cast_motion(params)
    if result.size() < 2 or result[0] >= 1.0:
        return
    var safe: float = result[0]
    var unsafe: float = result[1]
    # 接触する面の法線を、ぶつかる位置での接触情報から求める
    params.transform.origin += motion * unsafe
    params.motion = Vector3.ZERO
    var rest := space.get_rest_info(params)
    if rest.is_empty():
        return
    var n: Vector3 = rest["normal"]
    # 面に向かう速さ
    var approach := -linear_velocity.dot(n)
    if approach <= 0.0:
        return
    # 面に届くまでに許される、面に向かう方向の移動量。そこで止まる速さまで、面に向かう成分だけを減らす
    var allowed := maxf((motion * safe).dot(-n) - SWEEP_MARGIN, 0.0)
    var target := allowed / delta
    if target < approach:
        linear_velocity += n * (approach - target)
        # 激突の音の判定用に、この後しばらく速度変化を足し合わせる
        _sweep_dv_timer = SWEEP_CRASH_WINDOW

# 壁などに当たって水平の速度が急に変わったら激突の音を鳴らす
# 上下方向は除く（ジャンプの着地で鳴らさないため）
func _check_crash(delta: float) -> void:
    _crash_cooldown = maxf(_crash_cooldown - delta, 0.0)
    _sweep_dv_timer -= delta
    if _sweep_dv_timer <= 0.0:
        _sweep_dv_sum = 0.0
    if sleeping or freeze:
        return
    var dv := linear_velocity - _prev_velocity
    dv.y = 0.0
    # すり抜け防止が、ぶつかる直前の数フレームに分けて速度を落とすので、1フレームの変化だけでは激突を取りこぼす。
    # 働いてからしばらくは、フレームごとの変化の合計と比べて大きいほうを使う
    if _sweep_dv_timer > 0.0:
        _sweep_dv_sum += dv.length()
    var change := maxf(dv.length(), _sweep_dv_sum)
    if change < CRASH_MIN_DV or _crash_cooldown > 0.0:
        return
    _crash_sound.volume_db = CRASH_VOLUME_DB + linear_to_db(clampf(change / CRASH_FULL_DV, 0.3, 1.0))
    _crash_sound.pitch_scale = 1.0 + randf_range(-0.05, 0.05)
    _crash_sound.stream = BUMP_SOUNDS.pick_random()
    _crash_sound.play()
    _crash_cooldown = CRASH_COOLDOWN
    _sweep_dv_sum = 0.0
    crash_count += 1


func _play_jump_sound() -> void:
    _jump_sound.stream = BUMP_SOUNDS.pick_random()
    _jump_sound.pitch_scale = 1.0 + randf_range(-0.08, 0.08)
    _jump_sound.play()


# パワーアップを反映したジャンプの初速 [m/s]
func _jump_speed() -> float:
    return JUMP_SPEED * PowerUps.JUMP_UP_MULTIPLIER if PowerUps.has("jump_up") else JUMP_SPEED


# パワーアップを反映した最高速度。集中線やカメラの演出の基準にも使う
func get_max_speed() -> float:
    return MAX_SPEED * PowerUps.TORQUE_SPEED_MULTIPLIER if PowerUps.has("torque") else MAX_SPEED


func _engine_power() -> float:
    return ENGINE_POWER * PowerUps.TORQUE_POWER_MULTIPLIER if PowerUps.has("torque") else ENGINE_POWER


func _is_on_ground() -> bool:
    for child in get_children():
        var wheel := child as VehicleWheel3D
        if wheel != null and wheel.is_in_contact():
            return true
    return false


# 機体ごとの設定。見た目のタイヤを物理ホイールの回転・ステアリング・サスペンションに合わせて動かす
# node: シーンに置いてある機体のノード名
# wheels の group: 上下とステアリングで動かすキャスター部分（前輪のみ。後輪は空で部品を直接動かす）
# wheels の parts: 1つ目がタイヤ、残りはタイヤと一緒に動く部品
const MODELS := {
    "neo": {
        "node": "ugokuita-neo",
        "wheels": {
            "VehicleWheel3D_FL": {
                "group": "Main Frame III v42/4944825545635 v13_1/4944825545635 v13",
                "parts": [
                    "Main Frame III v42/4944825545635 v13_1/4944825545635 v13/Wheel",
                    "Main Frame III v42/4944825545635 v13_1/4944825545635 v13/Body85",
                ],
            },
            "VehicleWheel3D_FR": {
                "group": "Main Frame III v42/4944825545635 v7(Mirror)_1/4944825545635 v7(Mirror)",
                "parts": [
                    "Main Frame III v42/4944825545635 v7(Mirror)_1/4944825545635 v7(Mirror)/Body1_029",
                    "Main Frame III v42/4944825545635 v7(Mirror)_1/4944825545635 v7(Mirror)/Body2_011",
                ],
            },
            "VehicleWheel3D_BL": {
                "group": "",
                "parts": [
                    "Main Frame III v42/VGEBY M365 1s v6_1/VGEBY M365 1s v6/Body48",
                    "Main Frame III v42/VGEBY M365 1s v6_1/VGEBY M365 1s v6/Body1_001",
                ],
            },
            "VehicleWheel3D_BR": {
                "group": "",
                "parts": [
                    "Main Frame III v42/VGEBY M365 1s v6(Mirror)_1/VGEBY M365 1s v6(Mirror)/Body2_008",
                    "Main Frame III v42/VGEBY M365 1s v6(Mirror)_1/VGEBY M365 1s v6(Mirror)/Body1_024",
                ],
            },
        },
    },
    "classic": {
        "node": "ugokuita-classic",
        "wheels": {
            "VehicleWheel3D_FL": {
                "group": "MainFrame - Reverse Prototype v12/STM-100 VS v4_1/STM-100 VS v4",
                "parts": ["MainFrame - Reverse Prototype v12/STM-100 VS v4_1/STM-100 VS v4/2_PART_100VS100VS_in_ASM_STM_100_VS_1/2_PART_100VS100VS_in_ASM_STM_100_VS/Body149"],
            },
            "VehicleWheel3D_FR": {
                "group": "MainFrame - Reverse Prototype v12/STM-100 VS v4_2/STM-100 VS v42",
                "parts": ["MainFrame - Reverse Prototype v12/STM-100 VS v4_2/STM-100 VS v42/2_PART_100VS100VS_in_ASM_STM_100_VS_12/2_PART_100VS100VS_in_ASM_STM_100_VS2/Body153"],
            },
            "VehicleWheel3D_BL": {
                "group": "",
                "parts": [
                    "MainFrame - Reverse Prototype v12/350W Hub Motor v10_1/350W Hub Motor v10/Body32",
                    "MainFrame - Reverse Prototype v12/350W Hub Motor v10_1/350W Hub Motor v10/Body62",
                    "MainFrame - Reverse Prototype v12/350W Hub Motor v10_1/350W Hub Motor v10/Body9",
                    "MainFrame - Reverse Prototype v12/350W Hub Motor v10_1/350W Hub Motor v10/Body102",
                ],
            },
            "VehicleWheel3D_BR": {
                "group": "",
                "parts": [
                    "MainFrame - Reverse Prototype v12/350W Hub Motor v10_2/350W Hub Motor v102/Body34",
                    "MainFrame - Reverse Prototype v12/350W Hub Motor v10_2/350W Hub Motor v102/Body63",
                    "MainFrame - Reverse Prototype v12/350W Hub Motor v10_2/350W Hub Motor v102/Body92",
                    "MainFrame - Reverse Prototype v12/350W Hub Motor v10_2/350W Hub Motor v102/Body103",
                ],
            },
        },
    },
}

# ステアリングの見た目の向き（左入力でsteering > 0）
const STEER_SIGN := 1.0

# {wheel, group, group_rest, group_pivot, parts: [{node, rest}], pivot, axis, angle, tire_center_body, tire_radius}
var _visual_wheels: Array[Dictionary] = []

func _ready() -> void:
    add_to_group("player")
    _setup_run_sound()
    _jump_sound = AudioStreamPlayer3D.new()
    _jump_sound.unit_size = 3.0
    _jump_sound.bus = "SE"
    add_child(_jump_sound)
    _drift_charge_sound = AudioStreamPlayer3D.new()
    _drift_charge_sound.unit_size = 3.0
    _drift_charge_sound.bus = "SE"
    var charge_stream := DRIFT_CHARGE_SOUND.duplicate() as AudioStreamOggVorbis
    # 最後の部分を繰り返し、ドリフトが音より長く続いても鳴り続けるようにする
    charge_stream.loop = true
    charge_stream.loop_offset = CHARGE_LOOP_START
    _drift_charge_sound.stream = charge_stream
    _drift_charge_sound.volume_db = DRIFT_CHARGE_VOLUME_DB
    # 3Dの音は max_db（既定 +3dB）で頭打ちになるので、音量の設定値まで出せるようにする
    _drift_charge_sound.max_db = DRIFT_CHARGE_VOLUME_DB
    add_child(_drift_charge_sound)
    _drift_dash_sound = AudioStreamPlayer3D.new()
    _drift_dash_sound.unit_size = 3.0
    _drift_dash_sound.bus = "SE"
    _drift_dash_sound.stream = DRIFT_DASH_SOUND
    _drift_dash_sound.volume_db = DRIFT_DASH_VOLUME_DB
    # 3Dの音は max_db（既定 +3dB）で頭打ちになるので、音量の設定値まで出せるようにする
    _drift_dash_sound.max_db = DRIFT_DASH_VOLUME_DB
    add_child(_drift_dash_sound)
    # 3Dの音は max_db（既定 +3dB）で頭打ちになり、距離でも小さくなるため、激突の音は位置を持たない音で鳴らす
    _crash_sound = AudioStreamPlayer.new()
    _crash_sound.bus = "SE"
    add_child(_crash_sound)
    var exhaust := JetExhaustScript.new()
    exhaust.name = "JetExhaust"
    add_child(exhaust)
    # ドリフトの後で戻せるよう、各ホイールの元の摩擦を覚えておく
    for child in get_children():
        var wheel := child as VehicleWheel3D
        if wheel != null:
            _wheel_friction[wheel] = wheel.wheel_friction_slip
    var sparks := DriftSparksScript.new()
    sparks.name = "DriftSparks"
    add_child(sparks)
    var config: Dictionary = MODELS[robot_key]
    var model := get_node_or_null(NodePath(config["node"])) as Node3D
    if model == null:
        push_warning("機体のノードが見つからない: %s" % config["node"])
        return
    _setup_visual_wheels(model, config["wheels"])
    PlayerSwitch.on_player_ready(self)


func _setup_visual_wheels(model: Node3D, wheels: Dictionary) -> void:
    _visual_wheels.clear()
    var body_inv := global_transform.affine_inverse()
    for wheel_name in wheels:
        var wheel := get_node_or_null(NodePath(wheel_name)) as VehicleWheel3D
        if wheel == null:
            push_warning("%s が見つからない" % wheel_name)
            continue
        var info: Dictionary = wheels[wheel_name]
        var parts: Array[Dictionary] = []
        var pivot := Vector3.ZERO
        var axis := Vector3.RIGHT
        var tire_center_body := Vector3.ZERO
        var tire_radius := 0.0
        var group_pivot := Vector3.ZERO
        var moved_parent: Node3D = null
        var group: Node3D = null
        if info["group"] != "":
            group = model.get_node_or_null(NodePath(info["group"])) as Node3D
            if group == null:
                push_warning("キャスターが見つからない: %s" % info["group"])
        for i in info["parts"].size():
            var path: String = info["parts"][i]
            var node := model.get_node_or_null(NodePath(path)) as MeshInstance3D
            if node == null:
                push_warning("タイヤの部品が見つからない: %s" % path)
                continue
            parts.append({"node": node, "rest": node.transform})
            # 1つ目（タイヤ）のAABB中心を回転の中心にし、車体のX軸を回転軸にする
            if i == 0:
                var parent := node.get_parent() as Node3D
                pivot = (node.transform * node.get_aabb()).get_center()
                axis = (parent.global_basis.inverse() * global_basis.x).normalized()
                var center_global := (node.global_transform * node.get_aabb()).get_center()
                tire_center_body = body_inv * center_global
                # 見た目のタイヤの半径（AABBの高さの半分）。下端を物理ホイールの下端に合わせるのに使う
                tire_radius = (node.global_transform * node.get_aabb()).size.y * 0.5
                if group != null:
                    group_pivot = group.get_parent().global_transform.affine_inverse() * center_global
        if parts.is_empty():
            continue
        if group != null:
            moved_parent = group.get_parent() as Node3D
        else:
            moved_parent = parts[0]["node"].get_parent() as Node3D
        _visual_wheels.append({
            "wheel": wheel, "group": group, "moved_parent": moved_parent,
            "group_rest": group.transform if group != null else Transform3D.IDENTITY,
            "group_pivot": group_pivot, "parts": parts, "pivot": pivot, "axis": axis,
            "angle": 0.0, "tire_center_body": tire_center_body,
            "tire_radius": tire_radius,
        })

func _setup_run_sound() -> void:
    _run_sound = get_node_or_null("RunningSound") as AudioStreamPlayer3D
    if _run_sound == null:
        return
    # .tscn のノードなので、バスはコードで SE に振り分ける
    _run_sound.bus = "SE"
    var wav := _run_sound.stream as AudioStreamWAV
    if wav != null:
        wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
        wav.loop_begin = 0
        wav.loop_end = wav.data.size() / 2
    _run_sound.volume_db = -80.0
    _run_sound.play()

func _update_run_sound(delta: float) -> void:
    if _run_sound == null:
        return
    var wheel_speed := absf(_motor_speed)
    # ブースト中は最高速度（1）を超えて BOOST_MOTOR_RATIO まで上がる
    var ratio := clampf(wheel_speed / MAX_SPEED, 0.0, BOOST_MOTOR_RATIO)
    var base_ratio := minf(ratio, 1.0)
    var target := smoothstep(0.02, 0.25, base_ratio)
    _run_volume = move_toward(_run_volume, target, RUN_SOUND_FADE * delta)
    # 1を超えた分だけ音量を上げる（最大 +6dB）
    var boost_amount := clampf((ratio - 1.0) / (BOOST_MOTOR_RATIO - 1.0), 0.0, 1.0)
    _run_sound.volume_db = linear_to_db(maxf(_run_volume, 0.0001)) + 6.0 * boost_amount
    var pitch := lerpf(RUN_SOUND_MIN_PITCH, RUN_SOUND_MAX_PITCH, base_ratio)
    if ratio > 1.0:
        pitch = lerpf(RUN_SOUND_MAX_PITCH, RUN_SOUND_BOOST_PITCH, boost_amount)
    _run_sound.pitch_scale = pitch

func _process(delta: float) -> void:
    _update_run_sound(delta)
    var body_inv := global_transform.affine_inverse()
    for w in _visual_wheels:
        var wheel: VehicleWheel3D = w["wheel"]
        # 見た目のタイヤの下端を物理ホイールの下端に合わせる（タイヤの半径が違っても浮かない）
        # rigid_visual_wheels のときは上下させない（dy = 0）
        var dy: float = 0.0 if rigid_visual_wheels else (body_inv * wheel.global_position).y - wheel.wheel_radius + w["tire_radius"] - w["tire_center_body"].y
        var moved_parent: Node3D = w["moved_parent"]
        var to_local := moved_parent.global_basis.inverse()
        var offset_local: Vector3 = to_local * (global_basis * Vector3(0.0, dy, 0.0))
        var offset := Transform3D(Basis.IDENTITY, offset_local)

        # スリープ中は止まる直前の速度が残って回転数が0にならないので、回さない
        var spin := 0.0 if sleeping else wheel.get_rpm() / 60.0 * TAU
        if wheel.use_as_traction:
            spin = _motor_speed / wheel.wheel_radius
        var angle: float = fposmod(w["angle"] + spin * delta, TAU)
        w["angle"] = angle
        var rot := Basis(w["axis"], angle)
        var around := Transform3D(rot, w["pivot"] - rot * w["pivot"])

        var group: Node3D = w["group"]
        if group != null:
            # 前輪: キャスターを上下させてステアリング方向に向ける（回転はタイヤ中心まわり）
            var up_axis: Vector3 = (to_local * global_basis.y).normalized()
            var steer := Basis(up_axis, wheel.steering * STEER_SIGN)
            var gp: Vector3 = w["group_pivot"]
            group.transform = offset * Transform3D(steer, gp - steer * gp) * w["group_rest"]
            for part in w["parts"]:
                part["node"].transform = around * part["rest"]
        else:
            # 後輪: 部品を直接上下させる
            for part in w["parts"]:
                part["node"].transform = offset * around * part["rest"]
