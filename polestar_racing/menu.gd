extends Control
## Menu principal: corrida solo, multijogador online, garagem e configuracoes.

# ---------------------------------------------------------------- preview da pista
class TrackPreview extends Control:
    var _pts := PackedVector2Array()
    var _min := Vector2.ZERO
    var _span := Vector2.ONE
    var title := ""
    var info := ""

    func _init() -> void:
        custom_minimum_size = Vector2(0, 200)

    func set_track(id: String) -> void:
        var t := TrackInfo.new(id)
        _pts.clear()
        var i := 0
        while i < t.n:
            var p: Vector3 = t.pts[i]
            _pts.append(Vector2(p.x, p.z))
            i += 3
        var mn := _pts[0]
        var mx := _pts[0]
        for p in _pts:
            mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.y))
            mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.y))
        _min = mn
        _span = mx - mn
        title = str(t.data["name"])
        var rec: float = Game.records.get(id, INF)
        info = "%s\n%.1f km por volta\nSeu recorde: %s" % [str(t.data["desc"]), t.length / 1000.0, GameHUD.fmt(rec)]
        queue_redraw()

    func _draw() -> void:
        draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.3), true)
        var font := ThemeDB.fallback_font
        draw_string(font, Vector2(14, 34), title, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.5, 26, Color(0.25, 0.85, 1.0))
        var y := 64.0
        for line in info.split("\n"):
            draw_string(font, Vector2(14, y), line, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.42, 16, Color(0.9, 0.9, 0.9))
            y += 22.0 * (1.0 + float(line.length() > 36))
        if _pts.size() < 2:
            return
        var area := Rect2(size.x * 0.5, 12, size.x * 0.47, size.y - 24)
        var sc := minf(area.size.x / _span.x, area.size.y / _span.y)
        var off := area.position + (area.size - _span * sc) * 0.5
        var line_pts := PackedVector2Array()
        for p in _pts:
            line_pts.append((p - _min) * sc + off)
        line_pts.append(line_pts[0])
        draw_polyline(line_pts, Color(1, 1, 1, 0.9), 4.0, true)
        draw_circle(line_pts[0], 6.0, Color(1, 0.9, 0.2))


# ---------------------------------------------------------------- estado
var _holder: PanelContainer
var _screens := {}
var _current := ""
var _preview: CarPreview

var _name_label: Label
var _track_opt: OptionButton
var _track_prev: TrackPreview
var _solo_car_label: Label
var _car_name: Label
var _car_desc: Label
var _car_spec: Label
var _bars := {}
var _color_grid: GridContainer
var _status: Label
var _upnp_check: CheckBox
var _ip_edit: LineEdit
var _lan_list: VBoxContainer
var _lobby_info: Label
var _lobby_track: OptionButton
var _lobby_laps: HSlider
var _lobby_ai: HSlider
var _lobby_diff: OptionButton
var _lobby_start: Button
var _lobby_hint: Label
var _lobby_rows: VBoxContainer
var _lobby_car: OptionButton
var _lobby_ready: Button
var _scan_label: Label


func _ready() -> void:
    GameInput.ensure()
    var back_to_lobby := Net.return_to_lobby and Net.is_online()
    if not back_to_lobby:
        Net.leave()
    theme = UI.make_theme()
    set_anchors_preset(Control.PRESET_FULL_RECT)

    var bg := ColorRect.new()
    bg.color = Color(0.03, 0.05, 0.09)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(bg)
    var grad := Gradient.new()
    grad.set_color(0, Color(0.1, 0.25, 0.4, 0.55))
    grad.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
    var gt := GradientTexture2D.new()
    gt.gradient = grad
    gt.fill = GradientTexture2D.FILL_RADIAL
    gt.fill_from = Vector2(0.75, 0.55)
    gt.fill_to = Vector2(0.75, 1.1)
    var glow := TextureRect.new()
    glow.texture = gt
    glow.stretch_mode = TextureRect.STRETCH_SCALE
    glow.set_anchors_preset(Control.PRESET_FULL_RECT)
    glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(glow)

    _preview = CarPreview.new()
    _preview.set_anchors_preset(Control.PRESET_FULL_RECT)
    _preview.anchor_left = 0.36
    _preview.offset_left = 0.0
    add_child(_preview)

    var margin := MarginContainer.new()
    margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 26)
    add_child(margin)
    var left := VBoxContainer.new()
    left.custom_minimum_size = Vector2(620, 0)
    left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    margin.add_child(left)
    left.add_child(UI.label("POLESTAR RACING", 46, UI.ACCENT))
    left.add_child(UI.label("Corrida · IA · Multijogador online", 20, Color(0.75, 0.8, 0.9)))
    _holder = PanelContainer.new()
    _holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
    left.add_child(_holder)

    _screens["main"] = _wrap(_build_main())
    _screens["solo"] = _wrap(_build_solo())
    _screens["garage"] = _wrap(_build_garage())
    _screens["online"] = _wrap(_build_online())
    _screens["lobby"] = _wrap(_build_lobby())
    _screens["settings"] = _wrap(_build_settings())

    Net.players_changed.connect(_refresh_lobby)
    Net.lobby_changed.connect(_refresh_lobby)
    Net.connected_ok.connect(func(): _show("lobby"))
    Net.connection_failed.connect(func(): _show("online"))
    Net.server_closed.connect(func(): _show("online"))
    Net.kicked.connect(func(): _show("online"))
    Net.lan_servers_changed.connect(_refresh_lan)
    Net.status_changed.connect(_on_status)

    _preview.set_car(Game.car_id, Game.car_color)
    if back_to_lobby:
        Net.return_to_lobby = false
        _show("lobby")
        _refresh_lobby()
    else:
        _show("main")


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        if _current == "lobby":
            Net.leave()
            _show("online")
        elif _current != "main":
            _show("main")
        else:
            get_tree().quit()


func _wrap(c: Control) -> Control:
    var sc := ScrollContainer.new()
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
    c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sc.add_child(c)
    return sc


func _show(screen: String) -> void:
    if _current != "":
        _holder.remove_child(_screens[_current])
    _current = screen
    _holder.add_child(_screens[screen])
    if screen == "online":
        Net.start_lan_listen()
        _refresh_lan()
    else:
        Net.stop_lan_listen()
    if screen == "main":
        _name_label.text = "Piloto: " + Game.player_name
    elif screen == "solo":
        _sync_solo()
    elif screen == "garage":
        _refresh_garage()
    elif screen == "lobby":
        _refresh_lobby()


func _slider_row(caption: String, mn: int, mx: int, val: int, cb: Callable) -> HBoxContainer:
    var s := HSlider.new()
    s.min_value = mn
    s.max_value = mx
    s.step = 1
    s.value = val
    s.custom_minimum_size = Vector2(0, 44)
    var vl := UI.label(str(val), 24, UI.ACCENT)
    vl.custom_minimum_size = Vector2(44, 0)
    s.value_changed.connect(_on_slider.bind(vl, cb))
    var h := UI.row(caption, s)
    h.add_child(vl)
    h.set_meta("slider", s)
    h.set_meta("value_label", vl)
    return h


func _on_slider(v: float, vl: Label, cb: Callable) -> void:
    vl.text = str(int(v))
    cb.call(int(v))


# ---------------------------------------------------------------- tela: principal
func _build_main() -> Control:
    var vb := VBoxContainer.new()
    _name_label = UI.label("Piloto: " + Game.player_name, 24, UI.ACCENT)
    vb.add_child(_name_label)
    vb.add_child(UI.btn("Corrida solo (contra a IA)", func(): _show("solo"), true))
    vb.add_child(UI.btn("Multijogador online", func(): _show("online")))
    vb.add_child(UI.btn("Garagem", func(): _show("garage")))
    vb.add_child(UI.btn("Configurações", func(): _show("settings")))
    vb.add_child(UI.btn("Sair", func(): get_tree().quit()))
    return vb


# ---------------------------------------------------------------- tela: solo
func _build_solo() -> Control:
    var vb := VBoxContainer.new()
    vb.add_child(UI.label("Corrida solo", 32, UI.ACCENT))
    _track_opt = OptionButton.new()
    _track_opt.custom_minimum_size = Vector2(0, 54)
    for id in Catalog.TRACK_ORDER:
        _track_opt.add_item(str(TracksData.ALL[id]["name"]))
    _track_opt.item_selected.connect(_on_solo_track)
    vb.add_child(UI.row("Pista", _track_opt))
    _track_prev = TrackPreview.new()
    vb.add_child(_track_prev)
    vb.add_child(_slider_row("Voltas", 1, 10, Game.laps, func(v): Game.laps = v))
    vb.add_child(_slider_row("Adversários (IA)", 0, 11, Game.ai_count, func(v): Game.ai_count = v))
    var diff := OptionButton.new()
    diff.custom_minimum_size = Vector2(0, 54)
    for d in ["Fácil", "Normal", "Difícil"]:
        diff.add_item(d)
    diff.select(Game.difficulty)
    diff.item_selected.connect(func(i): Game.difficulty = i)
    vb.add_child(UI.row("Dificuldade", diff))
    _solo_car_label = UI.label("", 22)
    vb.add_child(_solo_car_label)
    vb.add_child(UI.btn("Trocar carro / cor (Garagem)", func(): _show("garage")))
    vb.add_child(UI.btn("LARGAR!", _start_solo, true))
    vb.add_child(UI.btn("Voltar", _back_main))
    return vb


func _sync_solo() -> void:
    var idx := Catalog.TRACK_ORDER.find(Game.track_id)
    _track_opt.select(maxi(idx, 0))
    _track_prev.set_track(Game.track_id)
    var d: Dictionary = Catalog.car_def(Game.car_id)
    _solo_car_label.text = "Carro: %s" % str(d["name"])


func _on_solo_track(i: int) -> void:
    Game.track_id = str(Catalog.TRACK_ORDER[i])
    _track_prev.set_track(Game.track_id)


func _start_solo() -> void:
    Game.save_settings()
    Game.mode = "solo"
    Game.start_race(Game.make_solo_setup())


# ---------------------------------------------------------------- tela: garagem
func _build_garage() -> Control:
    var vb := VBoxContainer.new()
    vb.add_child(UI.label("Garagem", 32, UI.ACCENT))
    var hb := HBoxContainer.new()
    var prev := UI.btn("◀", func(): _cycle_car(-1))
    prev.custom_minimum_size = Vector2(80, 62)
    var nxt := UI.btn("▶", func(): _cycle_car(1))
    nxt.custom_minimum_size = Vector2(80, 62)
    _car_name = UI.label("", 28, Color.WHITE)
    _car_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _car_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hb.add_child(prev)
    hb.add_child(_car_name)
    hb.add_child(nxt)
    vb.add_child(hb)
    _car_desc = UI.label("", 20, Color(0.8, 0.85, 0.95))
    vb.add_child(_car_desc)
    _car_spec = UI.label("", 20, Color(0.9, 0.9, 0.9))
    vb.add_child(_car_spec)
    for key in ["Aceleração", "Aderência", "Peso"]:
        var pb := ProgressBar.new()
        pb.max_value = 1.0
        pb.show_percentage = false
        pb.custom_minimum_size = Vector2(0, 22)
        _bars[key] = pb
        vb.add_child(UI.row(key, pb))
    vb.add_child(UI.label("Cor", 22, UI.ACCENT))
    _color_grid = GridContainer.new()
    _color_grid.columns = 6
    vb.add_child(_color_grid)
    var ob := Button.new()
    ob.text = "Original"
    ob.custom_minimum_size = Vector2(90, 56)
    ob.pressed.connect(_set_color.bind(-1))
    _color_grid.add_child(ob)
    for i in Catalog.COLORS.size():
        var b := Button.new()
        b.custom_minimum_size = Vector2(90, 56)
        var c: Color = Catalog.COLORS[i]["color"]
        for st in ["normal", "hover", "pressed"]:
            var sb := StyleBoxFlat.new()
            sb.bg_color = c
            sb.set_corner_radius_all(12)
            sb.set_border_width_all(3 if st != "normal" else 1)
            sb.border_color = Color.WHITE
            b.add_theme_stylebox_override(st, sb)
        b.pressed.connect(_set_color.bind(i))
        _color_grid.add_child(b)
    vb.add_child(UI.btn("Voltar", _back_main))
    return vb


func _cycle_car(dir: int) -> void:
    var ids: Array = Catalog.car_ids()
    var i: int = ids.find(Game.car_id)
    i = (i + dir + ids.size()) % ids.size()
    Game.car_id = str(ids[i])
    _refresh_garage()


func _set_color(i: int) -> void:
    Game.car_color = i
    _preview.set_car(Game.car_id, Game.car_color)


func _refresh_garage() -> void:
    var d: Dictionary = Catalog.car_def(Game.car_id)
    _car_name.text = str(d["name"])
    _car_desc.text = str(d["desc"])
    _car_spec.text = "Potência real: %s   ·   0-100 real: %s\nNo jogo a velocidade máxima é %d km/h" % [str(d["power"]), str(d["zero100"]), int(d["max_kmh"])]
    (_bars["Aceleração"] as ProgressBar).value = clampf(float(d["engine"]) / float(d["mass"]) / 11.0, 0.0, 1.0)
    (_bars["Aderência"] as ProgressBar).value = clampf(float(d["grip_rear"]) / 4.6, 0.0, 1.0)
    (_bars["Peso"] as ProgressBar).value = clampf(float(d["mass"]) / 2000.0, 0.0, 1.0)
    _preview.set_car(Game.car_id, Game.car_color)


# ---------------------------------------------------------------- tela: online
func _build_online() -> Control:
    var vb := VBoxContainer.new()
    vb.add_child(UI.label("Multijogador online", 32, UI.ACCENT))
    vb.add_child(UI.label("Um jogador cria a sala e os amigos entram. Todos no mesmo Wi-Fi (ou no hotspot de um celular) veem a sala aparecer sozinha na lista, sem internet.", 19, Color(0.8, 0.85, 0.95)))
    vb.add_child(UI.label("Sem Wi-Fi? Ligue o \"ponto de acesso\" (hotspot) em um celular e conecte os outros aparelhos nele. Depois é só criar e entrar na sala.", 17, Color(0.65, 0.75, 0.85)))
    _upnp_check = CheckBox.new()
    _upnp_check.text = "Abrir a porta do roteador automaticamente (UPnP)"
    _upnp_check.button_pressed = true
    vb.add_child(_upnp_check)
    vb.add_child(UI.btn("Criar sala", _on_host, true))
    vb.add_child(UI.label("Entrar em uma sala", 24, UI.ACCENT))
    _ip_edit = LineEdit.new()
    _ip_edit.placeholder_text = "IP do anfitrião (ex.: 192.168.0.10)"
    _ip_edit.custom_minimum_size = Vector2(0, 56)
    vb.add_child(_ip_edit)
    vb.add_child(UI.btn("Entrar", _on_join))
    vb.add_child(UI.label("Salas encontradas na rede local:", 20))
    _scan_label = UI.label("Procurando salas...", 17, Color(0.6, 0.8, 0.9))
    vb.add_child(_scan_label)
    _lan_list = VBoxContainer.new()
    vb.add_child(_lan_list)
    vb.add_child(UI.btn("Procurar de novo", func(): Net.refresh_lan()))
    _status = UI.label("", 19, Color(1, 0.85, 0.4))
    vb.add_child(_status)
    vb.add_child(UI.btn("Voltar", func(): _show("main")))
    return vb


func _on_status(msg: String) -> void:
    if _status != null:
        _status.text = msg
    if _lobby_info != null and _current == "lobby":
        _refresh_lobby()


func _on_host() -> void:
    Game.save_settings()
    if Net.host_game(_upnp_check.button_pressed):
        _show("lobby")


func _on_join() -> void:
    Game.save_settings()
    Net.join_game(_ip_edit.text)


func _refresh_lan() -> void:
    if _lan_list == null:
        return
    for c in _lan_list.get_children():
        c.queue_free()
    if Net.lan_servers.is_empty():
        _lan_list.add_child(UI.label("(nenhuma sala encontrada ainda)", 18, Color(0.6, 0.65, 0.7)))
    if _scan_label != null:
        _scan_label.text = "Procurando salas..." if Net.lan_servers.is_empty() else "%d sala(s) encontrada(s)" % Net.lan_servers.size()
    for ip in Net.lan_servers:
        var s: Dictionary = Net.lan_servers[ip]
        var tname := str(Catalog.track_data(str(s["track"]))["name"])
        var txt := "%s  ·  %s  ·  %s/%s" % [str(s["name"]), tname, str(s["players"]), str(s.get("max", 8))]
        var b := UI.btn(txt, _join_ip.bind(str(ip)))
        if int(s.get("v", Net.PROTOCOL)) != Net.PROTOCOL:
            b.text = txt + "  ·  versão diferente"
            b.disabled = true
        elif bool(s.get("in_race", false)):
            b.text = txt + "  ·  em corrida"
            b.disabled = true
        _lan_list.add_child(b)


func _join_ip(ip: String) -> void:
    _ip_edit.text = ip
    _on_join()


# ---------------------------------------------------------------- tela: sala (lobby)
func _build_lobby() -> Control:
    var vb := VBoxContainer.new()
    vb.add_child(UI.label("Sala", 32, UI.ACCENT))
    _lobby_info = UI.label("", 18, Color(1, 0.85, 0.4))
    vb.add_child(_lobby_info)
    _lobby_rows = VBoxContainer.new()
    vb.add_child(_lobby_rows)
    _lobby_car = OptionButton.new()
    _lobby_car.custom_minimum_size = Vector2(0, 54)
    for cid in Catalog.car_ids():
        _lobby_car.add_item(str(Catalog.car_def(str(cid))["name"]))
    _lobby_car.item_selected.connect(_on_lobby_car)
    vb.add_child(UI.row("Meu carro", _lobby_car))
    vb.add_child(UI.btn("Trocar cor do carro", _cycle_lobby_color))
    _lobby_ready = UI.btn("ESTOU PRONTO", _toggle_ready, true)
    vb.add_child(_lobby_ready)
    _lobby_track = OptionButton.new()
    _lobby_track.custom_minimum_size = Vector2(0, 54)
    for id in Catalog.TRACK_ORDER:
        _lobby_track.add_item(str(TracksData.ALL[id]["name"]))
    _lobby_track.item_selected.connect(func(_i): _push_lobby())
    vb.add_child(UI.row("Pista", _lobby_track))
    var lr := _slider_row("Voltas", 1, 10, 3, func(_v): _push_lobby())
    _lobby_laps = lr.get_meta("slider")
    vb.add_child(lr)
    var ar := _slider_row("IA", 0, 8, 3, func(_v): _push_lobby())
    _lobby_ai = ar.get_meta("slider")
    vb.add_child(ar)
    _lobby_diff = OptionButton.new()
    _lobby_diff.custom_minimum_size = Vector2(0, 54)
    for d in ["Fácil", "Normal", "Difícil"]:
        _lobby_diff.add_item(d)
    _lobby_diff.item_selected.connect(func(_i): _push_lobby())
    vb.add_child(UI.row("Dificuldade", _lobby_diff))
    _lobby_hint = UI.label("", 18, Color(0.7, 0.75, 0.85))
    vb.add_child(_lobby_hint)
    _lobby_start = UI.btn("INICIAR CORRIDA", func(): Net.host_start_race(), true)
    vb.add_child(_lobby_start)
    vb.add_child(UI.btn("Sair da sala", _leave_lobby))
    return vb


func _push_lobby() -> void:
    if not Net.is_host:
        return
    Net.set_lobby({"track": str(Catalog.TRACK_ORDER[_lobby_track.selected]), "laps": int(_lobby_laps.value),
            "ai": int(_lobby_ai.value), "diff": _lobby_diff.selected})


func _refresh_lobby() -> void:
    if _lobby_rows == null or _current != "lobby":
        return
    for c in _lobby_rows.get_children():
        c.queue_free()
    var ids: Array = Net.players.keys()
    ids.sort()
    var me := multiplayer.get_unique_id()
    for id in ids:
        var p: Dictionary = Net.players[id]
        var cname := str(Catalog.car_def(str(p["car"]))["name"])
        var mark := "✔" if bool(p.get("ready", false)) else "…"
        var ping_txt := "" if id == 1 and Net.is_host else "  %d ms" % int(p.get("ping", 0))
        var h := HBoxContainer.new()
        var lbl := UI.label("%s %s  (%s)%s%s" % [mark, str(p["name"]), cname, "  [anfitrião]" if id == 1 else "", ping_txt], 21)
        lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        h.add_child(lbl)
        if Net.is_host and id != 1:
            var kb := Button.new()
            kb.text = "Remover"
            kb.pressed.connect(Net.kick.bind(id))
            h.add_child(kb)
        _lobby_rows.add_child(h)
    var ci := Catalog.car_ids().find(str(Net.players.get(me, {}).get("car", Game.car_id)))
    if ci >= 0:
        _lobby_car.select(ci)
    var my_ready := bool(Net.players.get(me, {}).get("ready", false))
    _lobby_ready.text = "PRONTO ✔  (toque para cancelar)" if my_ready else "ESTOU PRONTO"
    var host := Net.is_host
    var info := ""
    if host:
        var ips := Net.local_ips()
        info = "IP na rede local: %s\n" % (", ".join(ips) if ips.size() > 0 else "?")
        if Net.public_ip != "":
            info += "IP pela internet: %s\n" % Net.public_ip
        info += "Porta: %d (UDP)\n" % Net.PORT
    info += Net.status
    _lobby_info.text = info
    var l: Dictionary = Net.lobby
    var idx := Catalog.TRACK_ORDER.find(str(l.get("track", "verde")))
    _lobby_track.select(maxi(idx, 0))
    _lobby_laps.set_value_no_signal(float(l.get("laps", 3)))
    (_lobby_laps.get_parent().get_meta("value_label") as Label).text = str(int(l.get("laps", 3)))
    _lobby_ai.set_value_no_signal(float(l.get("ai", 3)))
    (_lobby_ai.get_parent().get_meta("value_label") as Label).text = str(int(l.get("ai", 3)))
    _lobby_diff.select(int(l.get("diff", 1)))
    _lobby_track.disabled = not host
    _lobby_diff.disabled = not host
    _lobby_laps.editable = host
    _lobby_ai.editable = host
    _lobby_start.visible = host
    _lobby_ready.visible = not host
    var everyone := Net.all_ready()
    _lobby_start.disabled = not everyone
    _lobby_start.text = "INICIAR CORRIDA" if everyone else "Aguardando todos ficarem prontos..."
    _lobby_hint.text = "" if host else ("Aguardando o anfitrião iniciar a corrida..." if my_ready else "Toque em ESTOU PRONTO quando quiser correr.")


# ---------------------------------------------------------------- tela: configuracoes
func _build_settings() -> Control:
    var vb := VBoxContainer.new()
    vb.add_child(UI.label("Configurações", 32, UI.ACCENT))
    var name_edit := LineEdit.new()
    name_edit.text = Game.player_name
    name_edit.max_length = 16
    name_edit.custom_minimum_size = Vector2(0, 56)
    name_edit.text_changed.connect(func(t): Game.player_name = t if t.strip_edges() != "" else "Piloto")
    vb.add_child(UI.row("Seu nome", name_edit))
    var q := OptionButton.new()
    q.custom_minimum_size = Vector2(0, 54)
    for d in ["Baixa (mais rápido)", "Média", "Alta (sombras fortes)"]:
        q.add_item(d)
    q.select(Game.quality)
    q.item_selected.connect(func(i): Game.quality = i)
    vb.add_child(UI.row("Gráficos", q))
    var vr := _slider_row("Volume", 0, 100, int(Game.volume * 100.0), _set_volume)
    vb.add_child(vr)
    vb.add_child(UI.label("Dica: se estiver lento no tablet, use Gráficos = Baixa.", 18, Color(0.7, 0.75, 0.85)))
    vb.add_child(UI.btn("Voltar", _back_main, true))
    return vb


func _back_main() -> void:
    Game.save_settings()
    _show("main")


func _on_lobby_car(i: int) -> void:
    var ids: Array = Catalog.car_ids()
    Game.car_id = str(ids[i])
    Net.update_profile()


func _cycle_lobby_color() -> void:
    var nc := Game.car_color + 1
    Game.car_color = -1 if nc >= Catalog.COLORS.size() else nc
    Net.update_profile()


func _toggle_ready() -> void:
    var me := multiplayer.get_unique_id()
    Net.set_ready(not bool(Net.players.get(me, {}).get("ready", false)))


func _leave_lobby() -> void:
    Net.leave()
    _show("online")


func _set_volume(v: int) -> void:
    Game.volume = float(v) / 100.0
    Game.apply_audio()
