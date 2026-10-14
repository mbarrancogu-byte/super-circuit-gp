extends Node3D
## ============================================================
## SUPER CIRCUIT GP — port a Godot 4 (GDScript)
## Mismo modelo de física arcade y trazados que la versión web.
## ============================================================

const RW := 15.0            # semiancho de pista
const ACCEL := 135.0
const TOPV := 135.0
const N_SAMPLES := 640

# ---------- Estado ----------
var playing := false
var stage := 1
var t0 := 0.0
var race_t := 0.0
var finished := false

var path_pts : PackedVector3Array
var path_tan : PackedVector3Array
var path_len := 0
var gates : Array = []
var cp_idx := 0
var path_idx := 0
var last_idx := 0
var wrong_way := 0.0
var offroad := 0.0
var obstacles : Array = []        # {x, z, r}
var track_cx := 0.0
var track_cz := 0.0
var track_span_x := 1.0
var track_span_z := 1.0
var cam_zoom := 0.12              # 0 = coche de cerca · 1 = circuito entero
var cam_zoom_t := 0.12

var car_x := 0.0
var car_z := 0.0
var car_a := 0.0
var car_vx := 0.0
var car_vz := 0.0
var gear := 1                # caja automática: marcha actual
var shift_t := 0.0           # micro-corte de potencia al cambiar
var assist_brake := true     # freno asistido antes de curvas cerradas
var assist_steer := true     # asistencia de dirección a alta velocidad
var sound_on := true         # sonido del motor
var snd_btn : Button

# Modelos de F1: misma silueta, livery = tinte del sprite
const CARS : Array = [
	{ "name": "ORIGINAL", "col": Color(1, 1, 1) },
	{ "name": "SCARLET",  "col": Color(1, 0.27, 0.22) },
	{ "name": "AZUR",     "col": Color(0.31, 0.69, 1) },
	{ "name": "SOLAR",    "col": Color(1, 0.82, 0.25) },
	{ "name": "VERDE",    "col": Color(0.25, 0.91, 0.56) },
	{ "name": "VIOLA",    "col": Color(0.75, 0.44, 1) },
	{ "name": "ONYX",     "col": Color(0.53, 0.56, 0.63) },
]
var car_idx := 0
var dmg := 0.0               # daño del coche 0-100
var lb_dmg : Label
var steer_v := 0.0
var gas_v := 0.0
var brake_v := 0.0
var hb_v := false

# ---------- Nodos ----------
var cam : Camera3D
var sun : DirectionalLight3D
var wenv : WorldEnvironment
var world : Node3D
var car_spr : Sprite3D
var head_spot : SpotLight3D
var gate_arrows : Array = []
var skid_pool : Array = []
var dust_pool : Array = []
var rng := RandomNumberGenerator.new()

# ---------- HUD ----------
var hud : CanvasLayer
var lb_stage : Label
var lb_time : Label
var lb_cp : Label
var lb_wrong : Label
var lb_speed : Label
var lb_gear : Label
var lb_count : Label
var lb_toast : Label
var minimap : MiniMap
var menu : CenterContainer
var menu_cover : TextureRect
var results : CenterContainer
var lb_res_title : Label
var lb_res_time : Label
var lb_res_new : Label
var toast_t := 0.0

# ---------- Audio ----------
var eng_play : AudioStreamGeneratorPlayback
var eng_phase := 0.0

var rng_state := 1

func srand(seed : int) -> void:
	rng_state = seed & 0x7fffffff
	if rng_state == 0: rng_state = 1

func rnd(a := 0.0, b := 1.0) -> float:
	rng_state = (rng_state * 1103515245 + 12345) & 0x7fffffff
	return a + (b - a) * float(rng_state) / 2147483647.0

func _ready() -> void:
	_load_car()
	_build_scene()
	_build_hud()
	_build_menu()
	_init_audio()

func _build_scene() -> void:
	wenv = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0x06 / 255.0, 0x0a / 255.0, 0x16 / 255.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.44, 0.62)
	env.ambient_light_energy = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color(0x06 / 255.0, 0x0a / 255.0, 0x16 / 255.0)
	env.fog_density = 0.002
	wenv.environment = env
	add_child(wenv)

	sun = DirectionalLight3D.new()
	sun.light_color = Color(0.62, 0.70, 0.87)
	sun.light_energy = 0.45
	sun.rotation_degrees = Vector3(-55, 25, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 300
	add_child(sun)

	cam = Camera3D.new()
	cam.fov = 66
	cam.far = 2400
	cam.current = true
	add_child(cam)

	# Sprite del F1 tumbado en el suelo (nariz = fondo de la imagen → +Z)
	car_spr = Sprite3D.new()
	car_spr.texture = load("res://f1.png")
	car_spr.pixel_size = 0.0145
	car_spr.rotation_degrees.x = -90
	car_spr.shaded = true
	add_child(car_spr)

	# Foco delantero: charco de luz delante del morro, también de día
	head_spot = SpotLight3D.new()
	head_spot.light_color = Color(1, 0.88, 0.66)
	head_spot.light_energy = 3.2
	head_spot.spot_range = 90
	head_spot.spot_angle = 34
	head_spot.shadow_enabled = true
	add_child(head_spot)



# ==================== PISTAS ====================
const T1W := 560.0
var circ_w := 560.0
var circ_h := 560.0 * 682.0 / 1024.0

# Circuito de archivo para la etapa s: circuitos.js (window.CIRCUITOS=[{name,img,ar,pts}]) o track1.js (legado)
func _circuit_at(s : int) -> Variant:
	if FileAccess.file_exists("res://circuitos.js"):
		var txt := FileAccess.get_file_as_string("res://circuitos.js")
		var a := txt.find("["); var b := txt.rfind("]")
		if a >= 0 and b > a:
			var arr = JSON.parse_string(txt.substr(a, b - a + 1))
			if arr is Array and s <= arr.size() and arr[s - 1] is Dictionary:
				return arr[s - 1]
	if s == 1 and FileAccess.file_exists("res://track1.js"):
		var txt2 := FileAccess.get_file_as_string("res://track1.js")
		var a2 := txt2.find("["); var b2 := txt2.rfind("]")
		if a2 >= 0 and b2 > a2:
			var arr2 = JSON.parse_string(txt2.substr(a2, b2 - a2 + 1))
			if arr2 is Array:
				return { "pts": arr2, "img": "fondo.jpg", "ar": 0.666, "name": "CIRCUITO 01" }
	return null

func gen_track(s : int) -> void:
	var pts : Array[Vector3] = []
	var circ = _circuit_at(stage)
	if circ:
		# Circuito de archivo sobre foto aérea: coords normalizadas → mundo centrado
		circ_w = T1W; circ_h = T1W * float(circ.get("ar", 0.666))
		for pv in circ["pts"]:
			pts.append(Vector3((float(pv[0]) - 0.5) * circ_w, 0, (float(pv[1]) - 0.5) * circ_h))
	else:
		# Rally procedural: anillo irregular con jitter en radios y ángulos
		srand(s)
		for i in 12:
			var a := float(i) / 12.0 * TAU + rnd(-0.14, 0.14)
			var r := 300 + rnd(-75, 75)
			pts.append(Vector3(cos(a) * r, 0, sin(a) * r))

	var curve := Curve3D.new()
	curve.bake_interval = 4.0
	for p in pts: curve.add_point(p)
	curve.add_point(pts[0])          # cierra el lazo
	var baked := curve.get_baked_points()
	var m := baked.size()
	path_len = N_SAMPLES
	path_pts = PackedVector3Array()
	path_tan = PackedVector3Array()
	for i in path_len:
		var q := baked[(i * m / path_len) % m]
		var qn := baked[((i + 1) * m / path_len) % m]
		var tan := (qn - q).normalized()
		path_pts.append(q)
		path_tan.append(tan)
	gates = [int(path_len * 0.33), int(path_len * 0.66), 0]
	var mnx := 1e9; var mxx := -1e9; var mnz := 1e9; var mxz := -1e9
	for p in path_pts:
		mnx = minf(mnx, p.x); mxx = maxf(mxx, p.x)
		mnz = minf(mnz, p.z); mxz = maxf(mxz, p.z)
	track_cx = (mnx + mxx) / 2; track_cz = (mnz + mxz) / 2
	track_span_x = mxx - mnx + 60; track_span_z = mxz - mnz + 60

func near_road(x : float, z : float, margin : float) -> bool:
	for i in range(0, path_len, 4):
		var p := path_pts[i]
		var dx := p.x - x; var dz := p.z - z
		if dx * dx + dz * dz < (RW / 2 + margin) * (RW / 2 + margin):
			return true
	return false

# Cinta horizontal sobre la curva (CON índice — nunca sopa de triángulos)
func ribbon(edges : Array, half_w : float, y : float, col : Color, tex = null) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := path_len
	for i in n + 1:
		var p : Vector3 = path_pts[i % n]
		var pn : Vector3 = path_pts[(i + 1) % n]
		var t : Vector3 = path_tan[i % n]
		var nx := -t.z; var nz := t.x
		var seg := (pn - p).length()
		var turn : float = t.x * ((path_tan[(i + 1) % n]).z) - t.z * ((path_tan[(i + 1) % n]).x)
		var r_est : float = seg / maxf(absf(turn), 1e-3)
		var e_in : float = clampf(r_est * 0.8, 3.0, half_w)
		for e in edges:
			var off : float = e
			if e > 0 and turn > 0: off = minf(e, e_in)
			elif e < 0 and turn < 0: off = maxf(e, -e_in)
			st.set_uv(Vector2(0, i * 0.18))
			st.add_vertex(Vector3(p.x + nx * off, y, p.z + nz * off))
			st.set_uv(Vector2(1, i * 0.18))
			st.add_vertex(Vector3(p.x - nx * off, y, p.z - nz * off))
	# índices: cada muestra empareja verts [a,b]
	var stride := edges.size() * 2
	for i in n:
		var b0 := i * stride
		for e in edges.size():
			var k := b0 + e * 2
			st.add_index(k); st.add_index(k + 1); st.add_index(k + stride)
			st.add_index(k + 1); st.add_index(k + stride + 1); st.add_index(k + stride)
	st.generate_normals()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if tex: mat.albedo_texture = tex
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	return mi

func make_asphalt_tex() -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	img.fill(Color(0.10, 0.11, 0.14))
	for i in 700:
		var v := rnd(0.08, 0.3)
		img.set_pixel(randi() % 128, randi() % 128, Color(v, v, minf(1.0, v * 1.15)))
	return ImageTexture.create_from_image(img)

func build_world() -> void:
	if world: world.queue_free()
	world = Node3D.new()
	add_child(world)
	obstacles = []
	gate_arrows = []
	var circ = _circuit_at(stage)
	var traced := circ != null

	# Terreno (solo de noche; el circuito trazado usa la foto aérea)
	if not traced:
		var ter := MeshInstance3D.new()
		var tp := PlaneMesh.new(); tp.size = Vector2(2600, 2600)
		ter.mesh = tp
		var tm := StandardMaterial3D.new()
		tm.albedo_color = Color(0.13, 0.18, 0.1)
		ter.material_override = tm
		ter.position.y = -0.05
		ter.receive_shadows = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		world.add_child(ter)

	# Pista + arcén
	var road := ribbon([-RW / 2, RW / 2], RW / 2, 0.06,
		Color(0.75, 0.75, 0.78) if traced else Color(0.4, 0.42, 0.5), make_asphalt_tex())
	road.receive_shadows = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	world.add_child(road)
	var sh_col := Color(0.35, 0.54, 0.25) if traced else Color(0.6, 0.52, 0.4)
	world.add_child(ribbon([-RW / 2, -RW / 2 - 5.5, RW / 2, RW / 2 + 5.5], RW / 2 + 5.5, 0.03, sh_col))

	# Pianos rojo/blanco en los bordes de las curvas
	var curb_geo := PlaneMesh.new(); curb_geo.size = Vector2(3.6, 2.2)
	var curb_r := StandardMaterial3D.new(); curb_r.albedo_color = Color(0.85, 0.19, 0.19)
	var curb_w := StandardMaterial3D.new(); curb_w.albedo_color = Color(0.91, 0.91, 0.91)
	var cn := 0
	for i in range(0, path_len, 3):
		var p : Vector3 = path_pts[i]
		var t : Vector3 = path_tan[i]
		var t2 : Vector3 = path_tan[(i + 6) % path_len]
		var cross : float = t.x * t2.z - t.z * t2.x
		if absf(cross) < 0.28: continue
		var nx := -t.z; var nz := t.x
		var sides : Array = [1, -1] if absf(cross) > 0.45 else [sign(-cross)]
		for side in sides:
			var m := MeshInstance3D.new()
			m.mesh = curb_geo
			m.material_override = curb_r if (cn % 2) else curb_w
			cn += 1
			m.rotation.y = -atan2(t.z, t.x) + PI / 2
			m.position = Vector3(p.x + nx * side * (RW / 2 - 1.4), 0.14, p.z + nz * side * (RW / 2 - 1.4))
			world.add_child(m)

	if traced:
		# Fondo: foto aérea bajo el trazado (escala exacta del circuito)
		var bg_mat := StandardMaterial3D.new()
		bg_mat.albedo_texture = load("res://" + String(circ.get("img", "fondo.jpg")))
		var bg := MeshInstance3D.new()
		var bgp := PlaneMesh.new(); bgp.size = Vector2(circ_w, circ_h)
		bg.mesh = bgp; bg.material_override = bg_mat
		bg.position = Vector3(0, -0.08, 0)
		world.add_child(bg)
	else:
		_rally_extras()

	# Puertas de control: postes + flecha
	for gi in gates:
		var gp : Vector3 = path_pts[gi]
		var gt : Vector3 = path_tan[gi]
		var nx := -gt.z; var nz := gt.x
		var grp := Node3D.new()
		grp.position = Vector3(gp.x, 0, gp.z)
		grp.rotation.y = -atan2(gt.z, gt.x) + PI / 2
		var post_geo := CylinderMesh.new(); post_geo.top_radius = 0.3; post_geo.bottom_radius = 0.35; post_geo.height = 9
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(1, 0.65, 0.2)
		pm.emission_enabled = true; pm.emission = Color(1, 0.55, 0.15); pm.emission_energy_multiplier = 1.6
		for s in [-1, 1]:
			var post := MeshInstance3D.new()
			post.mesh = post_geo; post.material_override = pm
			post.position = Vector3(s * (RW / 2 + 1), 4.5, 0)
			grp.add_child(post)
		var ar := MeshInstance3D.new()
		var con := CylinderMesh.new(); con.top_radius = 2.6; con.bottom_radius = 0; con.height = 5
		var am := StandardMaterial3D.new()
		am.albedo_color = Color(1, 0.75, 0.2, 0.6)
		am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		am.emission_enabled = true; am.emission = Color(1, 0.65, 0.15); am.emission_energy_multiplier = 1.2
		am.cull_mode = BaseMaterial3D.CULL_DISABLED
		ar.mesh = con; ar.material_override = am
		ar.position = Vector3(0, 15, 0)
		ar.rotation_degrees.z = 180
		grp.add_child(ar)
		gate_arrows.append(ar)
		world.add_child(grp)

	# Línea de meta a cuadros
	var sl := MeshInstance3D.new()
	var slm := PlaneMesh.new(); slm.size = Vector2(16, 5)
	sl.mesh = slm
	sl.material_override = _check_mat()
	sl.position = Vector3(path_pts[0].x, 0.12, path_pts[0].z)
	sl.rotation.y = -atan2(path_tan[0].z, path_tan[0].x) + PI / 2
	world.add_child(sl)

func _check_mat() -> StandardMaterial3D:
	var img := Image.create(128, 32, false, Image.FORMAT_RGB8)
	for x in 128:
		for y in 32:
			img.set_pixel(x, y, Color.BLACK if ((x / 16 + y / 16) % 2) else Color.WHITE)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _rally_extras() -> void:
	for i in 130:
		var x := rnd(-700, 700); var z := rnd(-700, 700)
		if near_road(x, z, 9): continue
		var s := rnd(0.7, 1.6)
		var tr := MeshInstance3D.new()
		var tg := CylinderMesh.new(); tg.top_radius = 0; tg.bottom_radius = 5 * s; tg.height = 16 * s
		tr.mesh = tg
		var tm := StandardMaterial3D.new(); tm.albedo_color = Color(0.05, 0.14, 0.09)
		tr.material_override = tm
		tr.position = Vector3(x, 8 * s, z)
		world.add_child(tr)
		obstacles.append({x = x, z = z, r = 3.2 * s})

# ==================== HUD / UI ====================
func _chip(txt : String, pos : Vector2, anchor_flags : int = 0) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.position = pos
	l.visible = false
	hud.add_child(l)
	return l

class MiniMap extends Control:
	var pts : PackedVector3Array
	var gate_idx : Array = []
	var car_pos := Vector2.ZERO
	var cp := 0
	var mnx := 0.0; var mxx := 1.0; var mnz := 0.0; var mxz := 1.0
	func set_path(p : PackedVector3Array) -> void:
		pts = p
		mnx = 1e9; mxx = -1e9; mnz = 1e9; mxz = -1e9
		for v in p:
			mnx = minf(mnx, v.x); mxx = maxf(mxx, v.x)
			mnz = minf(mnz, v.z); mxz = maxf(mxz, v.z)
		queue_redraw()
	func _draw() -> void:
		if pts.is_empty(): return
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.08, 0.75), true)
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.78, 0.31, 0.4), false, 1)
		var sc := minf((size.x - 12) / maxf(0.001, mxx - mnx), (size.y - 12) / maxf(0.001, mxz - mnz))
		var ox := (size.x - (mxx - mnx) * sc) / 2 - mnx * sc
		var oy := (size.y - (mxz - mnz) * sc) / 2 - mnz * sc
		var xy := func(v : Vector3) -> Vector2: return Vector2(v.x * sc + ox, v.z * sc + oy)
		var pp := PackedVector2Array()
		for v in pts: pp.append(xy.call(v))
		pp.append(pp[0])
		draw_polyline(pp, Color(0.78, 0.75, 0.63, 0.85), 1.5)
		for k in gate_idx.size():
			var c := Color(0.49, 1, 0.69) if k == cp else (Color(1, 0.63, 0.19) if k == gate_idx.size() - 1 else Color(0.47, 0.59, 0.78, 0.5))
			draw_circle(xy.call(pts[gate_idx[k]]), 3.5 if k == cp else 2, c)
		draw_circle(xy.call(Vector3(car_pos.x, 0, car_pos.y)), 3, Color.WHITE)

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	lb_stage = _chip("ETAPA 1", Vector2(12, 10))
	lb_dmg = _chip("💥 0%", Vector2(12, 44))
	lb_dmg.add_theme_color_override("font_color", Color(1, 0.75, 0.55))
	snd_btn = Button.new()
	snd_btn.text = "🔊"
	snd_btn.position = Vector2(150, 8)
	snd_btn.custom_minimum_size = Vector2(40, 32)
	snd_btn.add_theme_font_size_override("font_size", 14)
	snd_btn.pressed.connect(func():
		sound_on = not sound_on
		snd_btn.text = "🔊" if sound_on else "🔇")
	hud.add_child(snd_btn)
	lb_time = _chip("0:00.0", Vector2(0, 10))
	lb_time.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lb_time.position.x = -50
	lb_cp = _chip("◯ ◯ ◯", Vector2(0, 10))
	lb_cp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lb_cp.position.x = -110
	lb_wrong = _chip("⚠ SENTIDO CONTRARIO", Vector2(0, 44))
	lb_wrong.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lb_wrong.position.x = -140
	lb_wrong.add_theme_color_override("font_color", Color(1, 0.4, 0.3))
	lb_speed = _chip("0 km/h", Vector2(0, 0))
	lb_speed.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	lb_speed.position = Vector2(-150, -90)
	lb_speed.add_theme_font_size_override("font_size", 34)
	lb_gear = _chip("MARCHA 1", Vector2(0, 0))
	lb_gear.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	lb_gear.position = Vector2(-110, -45)
	lb_gear.add_theme_font_size_override("font_size", 15)
	lb_count = _chip("", Vector2(0, 0))
	lb_count.set_anchors_preset(Control.PRESET_CENTER)
	lb_count.position = Vector2(-60, -90)
	lb_count.add_theme_font_size_override("font_size", 120)
	lb_toast = _chip("", Vector2(0, 100))
	lb_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lb_toast.position.x = -160
	lb_toast.add_theme_font_size_override("font_size", 17)
	minimap = MiniMap.new()
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.position = Vector2(-102, 10)
	minimap.custom_minimum_size = Vector2(92, 92)
	minimap.size = Vector2(92, 92)
	minimap.visible = false
	hud.add_child(minimap)
	_build_touch()

func _mb(txt : String) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_size_override("font_size", 20)
	b.custom_minimum_size = Vector2(320, 56)
	return b

func _build_menu() -> void:
	# Portada como fondo del menú
	menu_cover = TextureRect.new()
	var cover := menu_cover
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.texture = load("res://portada.png")
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cover.modulate = Color(1, 1, 1, 0.55)
	menu = CenterContainer.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	var title := Label.new()
	title.text = "SUPER CIRCUIT GP"
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(1, 0.75, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := Label.new()
	sub.text = "ETAPA · CONTRARRELOJ"
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(0.55, 0.6, 0.78))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title); vb.add_child(sub)
	var b1 := _mb("🏁 SALIR A PISTA")
	b1.pressed.connect(func(): start_stage(1))
	# Selector de modelo de F1: fila horizontal desplazable
	var car_scroll := ScrollContainer.new()
	car_scroll.custom_minimum_size = Vector2(0, 48)
	car_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	car_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var car_row := HBoxContainer.new()
	car_row.alignment = BoxContainer.ALIGNMENT_CENTER
	car_row.add_theme_constant_override("separation", 8)
	car_scroll.add_child(car_row)
	var car_btns := []
	for i in CARS.size():
		var cb := Button.new()
		cb.text = CARS[i].name
		cb.add_theme_font_size_override("font_size", 11)
		cb.custom_minimum_size = Vector2(90, 34)
		var idx := i
		cb.pressed.connect(func():
			car_idx = idx
			car_spr.modulate = CARS[idx].col
			for j in car_btns.size():
				car_btns[j].modulate = Color(1, 0.85, 0.4) if j == car_idx else Color(1, 1, 1)
			_save_car())
		car_btns.append(cb)
		car_row.add_child(cb)
	car_btns[car_idx].modulate = Color(1, 0.85, 0.4)
	car_spr.modulate = CARS[car_idx].col
	var b_abs := _mb("🛑 FRENO ASISTIDO: ON")
	b_abs.add_theme_font_size_override("font_size", 15)
	b_abs.pressed.connect(func():
		assist_brake = not assist_brake
		b_abs.text = "🛑 FRENO ASISTIDO: ON" if assist_brake else "🛑 FRENO ASISTIDO: OFF")
	var b_str := _mb("🎯 ASIST. DIRECCIÓN: ON")
	b_str.add_theme_font_size_override("font_size", 15)
	b_str.pressed.connect(func():
		assist_steer = not assist_steer
		b_str.text = "🎯 ASIST. DIRECCIÓN: ON" if assist_steer else "🎯 ASIST. DIRECCIÓN: OFF")
	var hint := Label.new()
	hint.text = "WASD/flechas pilotan · Espacio derrape · +/− zoom"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.4, 0.45, 0.6))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(b1); vb.add_child(car_scroll); vb.add_child(b_abs); vb.add_child(b_str); vb.add_child(hint)
	menu.add_child(vb)
	add_child(menu)

	# Pantalla de resultados
	results = CenterContainer.new()
	results.set_anchors_preset(Control.PRESET_FULL_RECT)
	results.visible = false
	var rv := VBoxContainer.new()
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	rv.add_theme_constant_override("separation", 16)
	lb_res_title = Label.new()
	lb_res_title.text = "META"
	lb_res_title.add_theme_font_size_override("font_size", 52)
	lb_res_title.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	lb_res_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb_res_new = Label.new()
	lb_res_new.add_theme_font_size_override("font_size", 18)
	lb_res_new.add_theme_color_override("font_color", Color(0.49, 1, 0.69))
	lb_res_new.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb_res_time = Label.new()
	lb_res_time.add_theme_font_size_override("font_size", 60)
	lb_res_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bn := _mb("▶ SIGUIENTE ETAPA")
	bn.pressed.connect(func(): results.visible = false; start_stage(stage + 1))
	var bm := _mb("MENÚ")
	bm.pressed.connect(func(): results.visible = false; menu.visible = true; menu_cover.visible = true)
	rv.add_child(lb_res_title); rv.add_child(lb_res_new); rv.add_child(lb_res_time)
	rv.add_child(bn); rv.add_child(bm)
	results.add_child(rv)
	add_child(results)

func _tbtn(txt : String, pos : Vector2, anchor : int, flag : String) -> void:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_size_override("font_size", 18)
	b.custom_minimum_size = Vector2(86, 86)
	b.set_anchors_preset(anchor)
	b.position = pos
	b.button_down.connect(func(): set(flag, _tval(flag, true)))
	b.button_up.connect(func(): set(flag, _tval(flag, false)))
	hud.add_child(b)
	b.visible = false
	b.set_meta("tb", true)

func _tval(flag : String, v : bool):
	match flag:
		"hb_v": return v
		_: return 1.0 if v else 0.0

func _build_touch() -> void:
	_tbtn("◀", Vector2(16, -200), Control.PRESET_BOTTOM_LEFT, "stL")
	_tbtn("▶", Vector2(112, -200), Control.PRESET_BOTTOM_LEFT, "stR")
	_tbtn("GAS", Vector2(-16, -200), Control.PRESET_BOTTOM_RIGHT, "gas_v")
	_tbtn("FRENO", Vector2(-112, -200), Control.PRESET_BOTTOM_RIGHT, "brake_v")
	_tbtn("HB", Vector2(-208, -200), Control.PRESET_BOTTOM_RIGHT, "hb_v")
	var zi := Button.new(); zi.text = "+"; zi.custom_minimum_size = Vector2(44, 40)
	zi.set_anchors_preset(Control.PRESET_TOP_RIGHT); zi.position = Vector2(-102, 108)
	zi.pressed.connect(func(): cam_zoom_t = maxf(0, cam_zoom_t - 0.12))
	var zo := Button.new(); zo.text = "−"; zo.custom_minimum_size = Vector2(44, 40)
	zo.set_anchors_preset(Control.PRESET_TOP_RIGHT); zo.position = Vector2(-54, 108)
	zo.pressed.connect(func(): cam_zoom_t = minf(1, cam_zoom_t + 0.12))
	for b in [zi, zo]: b.set_meta("tb", true); b.visible = false; hud.add_child(b)

var stL := false; var stR := false

func _show_game_ui(v : bool) -> void:
	for n in [lb_stage, lb_time, lb_cp, lb_speed, lb_gear, minimap]: n.visible = v
	for c in hud.get_children():
		if c is Button and c.has_meta("tb"): c.visible = v

# ==================== FLUJO ====================
func start_stage(n : int, seed : int = 0) -> void:
	stage = n
	gen_track(seed)
	build_world()
	_apply_day(_circuit_at(stage) != null)
	var p0 : Vector3 = path_pts[0]
	car_x = p0.x; car_z = p0.z
	car_a = atan2(path_tan[0].z, path_tan[0].x)
	car_vx = 0; car_vz = 0
	cam_zoom = cam_zoom_t
	path_idx = 0; last_idx = 0; cp_idx = 0
	wrong_way = 0; offroad = 0; gear = 1; shift_t = 0.0
	dmg = 0; _add_damage(0)
	finished = false
	for m in skid_pool: if is_instance_valid(m): m.queue_free()
	skid_pool.clear()
	for d in dust_pool: if is_instance_valid(d): d.queue_free()
	dust_pool.clear()
	menu.visible = false
	menu_cover.visible = false
	results.visible = false
	playing = true
	t0 = Time.get_ticks_msec() / 1000.0 + 3.6
	_show_game_ui(true)
	var circ = _circuit_at(stage)
	lb_stage.text = String(circ.get("name", "CIRCUITO")) if circ else "ETAPA %d" % stage
	lb_cp.text = "◯ ◯ ◯"
	minimap.set_path(path_pts)
	minimap.gate_idx = gates
	minimap.cp = 0

func _save_car() -> void:
	var f := FileAccess.open("user://opts.cfg", FileAccess.WRITE)
	f.store_var({ "car": car_idx }); f.close()

func _load_car() -> void:
	var f := FileAccess.open("user://opts.cfg", FileAccess.READ)
	if f and f.get_length() > 0:
		var d = f.get_var()
		if d is Dictionary: car_idx = int(d.get("car", 0))
		f.close()

func _add_damage(q : float) -> void:
	dmg = minf(100.0, dmg + q)
	lb_dmg.text = "💥 %d%%" % int(dmg)
	lb_dmg.add_theme_color_override("font_color",
		Color(1, 0.38, 0.31) if dmg > 70 else (Color(1, 0.69, 0.38) if dmg > 35 else Color(1, 0.75, 0.55)))

func _apply_day(day : bool) -> void:
	var env := wenv.environment
	if day:
		env.background_color = Color(0.5, 0.71, 0.86)
		env.fog_light_color = Color(0.5, 0.71, 0.86)
		env.ambient_light_color = Color(0.85, 0.91, 0.97)
		env.ambient_light_energy = 1.1
		sun.light_color = Color(1, 0.94, 0.82)
		sun.light_energy = 1.3
		sun.rotation_degrees = Vector3(-60, 30, 0)
	else:
		env.background_color = Color(0.024, 0.04, 0.086)
		env.fog_light_color = Color(0.024, 0.04, 0.086)
		env.ambient_light_color = Color(0.21, 0.27, 0.42)
		env.ambient_light_energy = 0.8
		sun.light_color = Color(0.62, 0.70, 0.87)
		sun.light_energy = 0.45
		sun.rotation_degrees = Vector3(-55, 25, 0)

func fmt_t(s : float) -> String:
	var mm := int(s / 60)
	return "%d:%02d.%d" % [mm, int(s) % 60, int(s * 10) % 10]

func finish_stage() -> void:
	playing = false
	finished = true
	lb_res_time.text = fmt_t(race_t)
	var key := "af1_best_%d" % stage
	var prev := FileAccess.open("user://best.cfg", FileAccess.READ)
	var best := 0.0
	if prev:
		var d : Dictionary = prev.get_var() if prev.get_length() > 0 else {}
		best = d.get(key, 0.0)
		prev.close()
	lb_res_new.text = "★ ¡NUEVO RÉCORD! ★" if (best == 0.0 or race_t < best) else ""
	if best == 0.0 or race_t < best:
		var d := {}
		var f := FileAccess.open("user://best.cfg", FileAccess.READ)
		if f and f.get_length() > 0: d = f.get_var(); f.close()
		d[key] = race_t
		var fw := FileAccess.open("user://best.cfg", FileAccess.WRITE)
		fw.store_var(d); fw.close()
	results.visible = true
	_show_game_ui(false)

func show_toast(msg : String) -> void:
	lb_toast.text = msg
	toast_t = 2.2

# ==================== AUDIO ====================
func _init_audio() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050
	gen.buffer_length = 0.25
	var p := AudioStreamPlayer.new()
	p.stream = gen
	p.volume_db = -18
	add_child(p)
	p.play()
	eng_play = p.get_stream_playback()

func _audio_tick(dt : float) -> void:
	if not eng_play: return
	var spd := Vector2(car_vx, car_vz).length()
	var rpm := fmod(spd * 3.4, 58.0) / 58.0            # vueltas dentro de la marcha
	var freq : float = 55 + rpm * 190 + gas_v * 14 + gear * 8
	var vol : float = (0.05 + gas_v * 0.05 + spd / TOPV * 0.03) if (playing and sound_on) else 0.0
	var frames := eng_play.get_frames_available()
	for i in frames:
		eng_phase += freq / 22050.0
		if eng_phase > 1: eng_phase -= 1
		var s := (eng_phase * 2 - 1) * vol          # diente de sierra
		eng_play.push_frame(Vector2(s, s))

# ==================== LÓGICA ====================
func _nearest_idx(from : int) -> int:
	var best := from; var bd := 1e12
	for k in range(-40, 41):
		var i : int = posmod(from + k, path_len)
		var p : Vector3 = path_pts[i]
		var d : float = (p.x - car_x) * (p.x - car_x) + (p.z - car_z) * (p.z - car_z)
		if d < bd: bd = d; best = i
	return best

func _process(dt : float) -> void:
	if not playing:
		if finished: pass
		return
	var now := Time.get_ticks_msec() / 1000.0
	var go := now >= t0
	race_t = maxf(0, now - t0)

	# Entradas
	var steer := 0.0
	if stL or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): steer -= 1
	if stR or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): steer += 1
	var gas : float = gas_v
	var brake : float = brake_v
	var hb := hb_v or Input.is_key_pressed(KEY_SPACE)
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): gas = 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): brake = 1.0
	if Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_KP_ADD): cam_zoom_t = maxf(0, cam_zoom_t - 0.12)
	if Input.is_key_pressed(KEY_MINUS) or Input.is_key_pressed(KEY_KP_SUBTRACT): cam_zoom_t = minf(1, cam_zoom_t + 0.12)

	var cf := cos(car_a); var sf := sin(car_a)
	var vf := car_vx * cf + car_vz * sf
	var vl := -car_vx * sf + car_vz * cf
	var spd := absf(vf)

	# Caja automática: cambia según km/h con micro-corte al subir
	var kmh0 := spd * 3.4
	var tgt_gear : int = clampi(int(kmh0 / 58) + 1, 1, 6)
	if tgt_gear != gear:
		gear = tgt_gear
		shift_t = 0.09
	if shift_t > 0:
		shift_t -= dt
		vf *= 1 - 2.2 * dt

	var steer_rate : float = (2.1 / (1 + spd * 0.028)) * (1.55 if hb else 1.0) * ((1 + spd * 0.017) if assist_steer else 1.0)
	car_a += steer * steer_rate * dt * (1 if vf >= -1 else -1)

	var gas_eff := gas if go else 0.0
	var dmg_mul : float = 1.0 - dmg * 0.0055           # el daño recorta potencia y punta
	var drag := 0.006 * vf * absf(vf)
	if gas_eff: vf += ACCEL * dmg_mul * dt * (1 - spd / (TOPV * dmg_mul))
	if brake: vf -= (95 if vf > 0 else ACCEL * 0.5) * dt
	if hb: vf -= vf * 0.7 * dt
	vf -= drag * dt * 0.5                  # arrastre suave: deja subir de marcha
	if not gas_eff and not brake: vf -= vf * 0.4 * dt
	if not go: vf = 0; vl = 0

	# Freno asistido: anticipa la curva y recorta velocidad si es demasiado cerrada
	if assist_brake and go and spd > 12:
		var look : int = mini(path_len >> 1, 8 + int(spd * 0.32))
		var p0t : Vector3 = path_tan[path_idx]
		var worst := 0.0
		var k := 4
		while k <= look:
			var pt : Vector3 = path_tan[(path_idx + k) % path_len]
			var cr := absf(p0t.x * pt.z - p0t.z * pt.x)   # ~seno del ángulo de giro
			if cr > worst: worst = cr
			k += 4
		var v_max : float = maxf(15.0, 96.0 - worst * 150.0)  # velocidad que aguanta la curva
		if spd > v_max: vf -= minf((spd - v_max) * 4.0, 135.0) * dt

	var grip := 1.4 if hb else (4.5 if offroad > 0.5 else 8.5)
	vl *= exp(-grip * dt)
	vl += steer * spd * dt * (0.5 if hb else 0.14)

	car_vx = cf * vf - sf * vl
	car_vz = sf * vf + cf * vl
	car_x += car_vx * dt; car_z += car_vz * dt

	# En pista o fuera
	path_idx = _nearest_idx(path_idx)
	var np : Vector3 = path_pts[path_idx]
	var d_road := Vector2(np.x - car_x, np.z - car_z).length()
	offroad += ((1.0 if d_road > RW / 2 + 1.5 else 0.0) - offroad) * minf(1, dt * 5)
	if offroad > 0.5:
		car_vx -= car_vx * 1.4 * dt; car_vz -= car_vz * 1.4 * dt
		if spd > 10: _add_damage(spd * 0.06 * dt)       # salirse del circuito daña el coche
	# Barrera del circuito: solo un margen fuera del asfalto, luego muro + daño
	var max_out := RW / 2 + 10.0
	if d_road > max_out:
		var kk := max_out / d_road
		car_x = np.x + (car_x - np.x) * kk
		car_z = np.z + (car_z - np.z) * kk
		var nx := (car_x - np.x) / max_out; var nz := (car_z - np.z) / max_out
		var vr : float = car_vx * nx + car_vz * nz
		if vr > 0:
			car_vx -= vr * nx * 1.5; car_vz -= vr * nz * 1.5     # rebote amortiguado
			if vr > 8: _add_damage(minf(14.0, vr * 0.35))

	# Obstáculos
	for o in obstacles:
		var dx : float = car_x - o.x; var dz : float = car_z - o.z
		var dd : float = sqrt(dx * dx + dz * dz)
		if dd < o.r + 2.5 and dd > 0.01:
			car_x = o.x + dx / dd * (o.r + 2.5)
			car_z = o.z + dz / dd * (o.r + 2.5)
			var vn : float = (car_vx * dx + car_vz * dz) / dd
			if vn < 0: _add_damage(minf(20.0, -vn * 0.55))
			if vn < 0:
				car_vx -= vn * dx / dd * 1.6
				car_vz -= vn * dz / dd * 1.6

	# Puertas
	var gi : int = gates[cp_idx]
	var d_gate := posmod(path_idx - gi, path_len)
	if d_gate > path_len / 2: d_gate -= path_len
	if abs(d_gate) < 10:
		cp_idx += 1
		if cp_idx >= gates.size():
			finish_stage()
			return
		show_toast("🏁 ¡ÚLTIMO SECTOR!" if cp_idx == gates.size() - 1 else "✔ PUNTO DE CONTROL %d/2" % cp_idx)
		lb_cp.text = "● ".repeat(cp_idx) + "◯ ".repeat(3 - cp_idx)
		minimap.cp = cp_idx

	# Sentido contrario
	if spd > 8:
		var adv := posmod(path_idx - last_idx + int(path_len / 2), path_len) - path_len / 2
		wrong_way = clampf(wrong_way + (dt * 4 if adv < -0.5 else -dt * 6), 0, 1)
	last_idx = path_idx
	lb_wrong.visible = wrong_way > 0.5

	# Derrape
	var sliding := absf(vl) > 9 or (hb and spd > 12)
	if sliding and spd > 10:
		_skid(car_x - cf * 3, car_z - sf * 3, -car_a + PI / 2)

	# HUD
	var kmh := int(spd * 3.4)
	lb_speed.text = "%d km/h" % kmh
	lb_gear.text = "MARCHA %d" % gear
	lb_time.text = fmt_t(race_t)
	lb_count.text = "" if go else str(maxi(1, int(ceil(t0 - now))))
	if not go and t0 - now < 0.6: lb_count.text = "¡YA!"

	# Coche
	car_spr.position = Vector3(car_x, 1.6, car_z)
	car_spr.rotation.y = PI / 2 - car_a
	# El foco flota alto mirando al suelo un poco por delante del morro
	var fdir := Vector2(cos(car_a), sin(car_a))
	head_spot.position = Vector3(car_x + fdir.x * 20, 22, car_z + fdir.y * 20)
	head_spot.look_at(Vector3(car_x + fdir.x * 42, 0, car_z + fdir.y * 42), Vector3.UP)


	# Puertas: parpadeo de la siguiente
	for k in gate_arrows.size():
		var ar : MeshInstance3D = gate_arrows[k]
		var next : bool = k == cp_idx
		ar.material_override.albedo_color.a = 0.6 + sin(now * 5.5) * 0.4 if next else 0.15
		ar.position.y = 15 + (sin(now * 3.3) * 1.5 if next else 0)

	# Marcas de derrape y polvo
	_fade_skids(dt)
	_fade_dust(dt)

	# Cámara cenital con zoom
	cam_zoom += (cam_zoom_t - cam_zoom) * minf(1, dt * 4)
	var zm := cam_zoom * cam_zoom
	var half_tan := tan(deg_to_rad(33))
	var aspect := get_viewport().get_visible_rect().size.x / get_viewport().get_visible_rect().size.y
	var fit_h : float = maxf(track_span_z, track_span_x / aspect) / (2 * half_tan) * 1.12
	var cam_h := 62 + spd * 0.45 + zm * maxf(0, fit_h - 62)
	var cx := car_x + (track_cx - car_x) * zm
	var cz := car_z + (track_cz - car_z) * zm
	cam.position = Vector3(cx, cam.position.y + (cam_h - cam.position.y) * minf(1, dt * 3), cz)
	var u := clampf((1 - cam_zoom) * 1.35, 0, 1)
	var ux := cf * u; var uz := sf * u - (1 - u)
	if Vector2(ux, uz).length() < 0.25: ux = 0; uz = -1
	var upv := Vector3(ux, 0, uz).normalized()
	cam.look_at(Vector3(cx, 0, cz), upv)
	if offroad > 0.4 and cam_zoom < 0.8:
		var sh2 := 0.5 * minf(1, spd / 40)
		cam.position.x += rnd(-sh2, sh2); cam.position.z += rnd(-sh2, sh2)
	var env := wenv.environment
	env.fog_density = 0.002 / maxf(0.4, cam.position.y / 80.0)

	# Sol sigue al coche (sombra local)
	sun.position = Vector3(car_x + 60, 200, car_z + 40)
	sun.look_at(Vector3(car_x, 0, car_z), Vector3.UP)

	# Minimapa
	minimap.car_pos = Vector2(car_x, car_z)
	minimap.queue_redraw()

	# Toast
	if toast_t > 0:
		toast_t -= dt
		lb_toast.visible = toast_t > 0 and playing

	_audio_tick(dt)

func _skid(x : float, z : float, a : float) -> void:
	var m : MeshInstance3D
	for s in skid_pool:
		if not s.visible: m = s; break
	if not m:
		if skid_pool.size() >= 240: m = skid_pool[0]
		else:
			m = MeshInstance3D.new()
			var q := PlaneMesh.new(); q.size = Vector2(1.5, 4.2)
			var mt := StandardMaterial3D.new()
			mt.albedo_color = Color(0.06, 0.05, 0.04, 0.7)
			mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.mesh = q; m.material_override = mt
			m.set_meta("life", 1.0)
			world.add_child(m)
			skid_pool.append(m)
	m.position = Vector3(x, 0.12, z)
	m.rotation.y = a
	m.material_override.albedo_color.a = 0.7
	m.set_meta("life", 1.0)
	m.visible = true

func _fade_skids(dt : float) -> void:
	for m in skid_pool:
		if not m.visible: continue
		var life : float = m.get_meta("life") - dt / 18.0
		m.set_meta("life", life)
		if life <= 0: m.visible = false
		else: m.material_override.albedo_color.a = 0.7 * minf(1, life * 3)

func _fade_dust(dt : float) -> void:
	pass
