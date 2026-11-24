extends Node
## Autoload "Net": multijogador online (ENet).
## - O anfitriao (host) cria a sala; amigos entram pelo IP (ou aparecem na lista da rede local).
## - Cada jogador simula o proprio carro e envia posicao ~20x/s; os outros veem uma copia suave.
## - A IA roda no anfitriao e tambem e enviada aos outros.
## - Abre a porta do roteador sozinho via UPnP quando disponivel.

signal players_changed()
signal lobby_changed()
signal connected_ok()
signal connection_failed()
signal server_closed()
signal player_left(id: int)
signal lan_servers_changed()
signal status_changed(msg: String)
signal kicked()
signal rejected(reason: String)

const PORT := 7777
const LAN_PORT := 7778
const MAX_PLAYERS := 8
const PROTOCOL := 3
const PROBE_EVERY := 1.0

var players := {}                   # id -> {name, color, car}
var lobby := {"track": "verde", "laps": 3, "ai": 3, "diff": 1}
var is_host := false
var race_scene: Node = null
var lan_servers := {}               # ip -> {name, track, players, t}
var public_ip := ""
var status := ""

var _upnp_thread: Thread
var _sock: PacketPeerUDP            # descoberta de salas (host responde, cliente procura)
var _role := ""                     # "host" | "client" | ""
var _bcast_t := 0.0
var _probe_t := 0.0
var _scan_t := 0.0
var _scan_queue: Array = []
var _ready_set := {}
var in_race := false                # a corrida ja comecou (ninguem novo entra)
var return_to_lobby := false        # depois da corrida volta para a sala
var _ping_t := 0.0


func _ready() -> void:
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.connected_to_server.connect(_on_connected)
    multiplayer.connection_failed.connect(_on_failed)
    multiplayer.server_disconnected.connect(_on_server_gone)


func is_online() -> bool:
    return multiplayer.multiplayer_peer is ENetMultiplayerPeer


func local_ips() -> Array:
    var out: Array = []
    for a in IP.get_local_addresses():
        var s := str(a)
        if s.contains(":"):
            continue
        if s.begins_with("192.168.") or s.begins_with("10.") or s.begins_with("172."):
            out.append(s)
    return out


func _set_status(msg: String) -> void:
    status = msg
    status_changed.emit(msg)


# ------------------------------------------------------------ host / join
func host_game(use_upnp: bool) -> bool:
    leave()
    var peer := ENetMultiplayerPeer.new()
    var err := peer.create_server(PORT, MAX_PLAYERS)
    if err != OK:
        _set_status("Nao foi possivel criar a sala (porta %d ocupada?)" % PORT)
        return false
    multiplayer.multiplayer_peer = peer
    is_host = true
    Game.mode = "online"
    players = {1: {"name": Game.player_name, "color": Game.car_color, "car": Game.car_id, "ready": true, "ping": 0}}
    in_race = false
    return_to_lobby = false
    lobby = {"track": Game.track_id, "laps": Game.laps, "ai": Game.ai_count, "diff": Game.difficulty}
    _start_discovery("host")
    if use_upnp:
        _set_status("Sala criada. Abrindo a porta no roteador (UPnP)...")
        _upnp_thread = Thread.new()
        _upnp_thread.start(_upnp_work)
    else:
        _set_status("Sala criada na porta %d." % PORT)
    players_changed.emit()
    return true


func join_game(ip: String) -> bool:
    leave()
    var peer := ENetMultiplayerPeer.new()
    var err := peer.create_client(ip.strip_edges(), PORT)
    if err != OK:
        _set_status("Endereco invalido.")
        return false
    multiplayer.multiplayer_peer = peer
    is_host = false
    Game.mode = "online"
    _set_status("Conectando em %s ..." % ip)
    return true


func leave() -> void:
    _stop_discovery()
    if _upnp_thread != null:
        _upnp_thread.wait_to_finish()
        _upnp_thread = null
    if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer is ENetMultiplayerPeer:
        multiplayer.multiplayer_peer.close()
    multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
    players.clear()
    _ready_set.clear()
    is_host = false
    race_scene = null
    public_ip = ""
    in_race = false
    return_to_lobby = false
    Game.mode = "solo"


func _on_connected() -> void:
    _set_status("Conectado!")
    rpc_id(1, "_srv_register", Game.player_name, Game.car_color, Game.car_id, PROTOCOL)
    connected_ok.emit()


func _on_failed() -> void:
    _set_status("Falha ao conectar. Confira o IP, a porta %d (UDP) e o Wi-Fi." % PORT)
    leave()
    connection_failed.emit()


func _on_server_gone() -> void:
    _set_status("O anfitriao fechou a sala.")
    leave()
    server_closed.emit()


func _on_peer_connected(id: int) -> void:
    pass


func _on_peer_disconnected(id: int) -> void:
    if multiplayer.is_server():
        players.erase(id)
        _ready_set.erase(id)
        _broadcast_players()
    player_left.emit(id)
    players_changed.emit()


# ------------------------------------------------------------ lobby RPCs
@rpc("any_peer", "call_remote", "reliable")
func _srv_register(pname: String, color: int, car: String, proto: int) -> void:
    if not multiplayer.is_server():
        return
    var id := multiplayer.get_remote_sender_id()
    var why := ""
    if proto != PROTOCOL:
        why = "Versao diferente do jogo. Atualize os dois aparelhos para a mesma versao."
    elif in_race:
        why = "A corrida ja comecou. Espere ela terminar para entrar."
    elif players.size() >= MAX_PLAYERS:
        why = "A sala esta cheia."
    if why != "":
        rpc_id(id, "_cl_rejected", why)
        get_tree().create_timer(0.5).timeout.connect(_drop_peer.bind(id))
        return
    if not CarsData.ALL.has(car):
        car = "p911ts"
    players[id] = {"name": pname.substr(0, 16), "color": clampi(color, -1, 63), "car": car, "ready": false, "ping": 0}
    _broadcast_players()
    rpc_id(id, "_cl_lobby", lobby)


@rpc("authority", "call_remote", "reliable")
func _cl_rejected(reason: String) -> void:
    _set_status(reason)
    rejected.emit(reason)
    leave()
    connection_failed.emit()


# ---- perfil e "pronto" na sala
func update_profile() -> void:
    if multiplayer.is_server():
        if players.has(1):
            players[1]["car"] = Game.car_id
            players[1]["color"] = Game.car_color
            players[1]["name"] = Game.player_name
            _broadcast_players()
    elif is_online():
        rpc_id(1, "_srv_profile", Game.player_name, Game.car_color, Game.car_id)


@rpc("any_peer", "call_remote", "reliable")
func _srv_profile(pname: String, color: int, car: String) -> void:
    if not multiplayer.is_server() or in_race:
        return
    var id := multiplayer.get_remote_sender_id()
    if not players.has(id) or not CarsData.ALL.has(car):
        return
    players[id]["name"] = pname.substr(0, 16)
    players[id]["color"] = clampi(color, -1, 63)
    players[id]["car"] = car
    players[id]["ready"] = false
    _broadcast_players()


func set_ready(v: bool) -> void:
    if multiplayer.is_server():
        return
    rpc_id(1, "_srv_set_ready", v)


@rpc("any_peer", "call_remote", "reliable")
func _srv_set_ready(v: bool) -> void:
    if not multiplayer.is_server():
        return
    var id := multiplayer.get_remote_sender_id()
    if players.has(id):
        players[id]["ready"] = v
        _broadcast_players()


func all_ready() -> bool:
    for id in players:
        if not bool(players[id].get("ready", false)):
            return false
    return true


func kick(id: int) -> void:
    if not multiplayer.is_server() or id == 1 or not players.has(id):
        return
    rpc_id(id, "_cl_kicked")
    get_tree().create_timer(0.4).timeout.connect(_drop_peer.bind(id))


func _drop_peer(id: int) -> void:
    if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
        (multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id)


@rpc("authority", "call_remote", "reliable")
func _cl_kicked() -> void:
    _set_status("O anfitriao removeu voce da sala.")
    leave()
    kicked.emit()
    server_closed.emit()


# ---- ping (o anfitriao mede e mostra na sala)
@rpc("authority", "call_remote", "unreliable")
func _cl_ping(t: int) -> void:
    rpc_id(1, "_srv_pong", t)


@rpc("any_peer", "call_remote", "unreliable")
func _srv_pong(t: int) -> void:
    if not multiplayer.is_server():
        return
    var id := multiplayer.get_remote_sender_id()
    if players.has(id):
        players[id]["ping"] = clampi(Time.get_ticks_msec() - t, 0, 999)


func _broadcast_players() -> void:
    rpc("_cl_players", players)
    players_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _cl_players(p: Dictionary) -> void:
    players = p
    players_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _cl_lobby(l: Dictionary) -> void:
    lobby = l
    lobby_changed.emit()


func set_lobby(l: Dictionary) -> void:
    lobby = l
    if multiplayer.is_server():
        rpc("_cl_lobby", l)
    lobby_changed.emit()


# ------------------------------------------------------------ start race
func host_start_race() -> void:
    if not multiplayer.is_server():
        return
    _stop_discovery()
    _ready_set.clear()
    in_race = true
    return_to_lobby = true
    var setup := Game.make_online_setup(players, lobby)
    rpc("_cl_begin", setup)
    Game.start_race(setup)


@rpc("authority", "call_remote", "reliable")
func _cl_begin(setup: Dictionary) -> void:
    Game.mode = "online"
    in_race = true
    return_to_lobby = true
    Game.start_race(setup)


## A cena de corrida chama isto quando terminou de carregar.
func scene_ready() -> void:
    if multiplayer.is_server():
        _ready_set[1] = true
        _check_all_ready()
        get_tree().create_timer(15.0).timeout.connect(_force_start)
    else:
        rpc_id(1, "_srv_ready")


func _force_start() -> void:
    if multiplayer.is_server() and race_scene != null and not race_scene.started:
        _cl_countdown()
        rpc("_cl_countdown")


@rpc("any_peer", "call_remote", "reliable")
func _srv_ready() -> void:
    if not multiplayer.is_server():
        return
    _ready_set[multiplayer.get_remote_sender_id()] = true
    _check_all_ready()


func _check_all_ready() -> void:
    for id in players:
        if not _ready_set.has(id):
            return
    if race_scene != null and not race_scene.started:
        rpc("_cl_countdown")
        _cl_countdown()


@rpc("authority", "call_remote", "reliable")
func _cl_countdown() -> void:
    if race_scene != null and not race_scene.started:
        race_scene.begin_countdown()


## Termina a corrida e volta para a sala (sem derrubar a conexao).
func finish_race_to_lobby() -> void:
    in_race = false
    race_scene = null
    _ready_set.clear()
    if multiplayer.is_server():
        for id in players:
            players[id]["ready"] = (id == 1)
        _start_discovery("host")
        _broadcast_players()


# ------------------------------------------------------------ state sync
func send_states(states: Array) -> void:
    if is_online():
        rpc("_rx_states", states)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rx_states(states: Array) -> void:
    if race_scene != null:
        race_scene.on_states(states)


# ------------------------------------------------------------ UPnP (thread)
func _upnp_work() -> void:
    var upnp := UPNP.new()
    var ok := false
    var ip := ""
    if upnp.discover(2000, 2, "InternetGatewayDevice") == UPNP.UPNP_RESULT_SUCCESS:
        var gw := upnp.get_gateway()
        if gw != null and gw.is_valid_gateway():
            var r1 := upnp.add_port_mapping(PORT, PORT, "PolestarRacing", "UDP")
            upnp.add_port_mapping(PORT, PORT, "PolestarRacing", "TCP")
            ok = r1 == UPNP.UPNP_RESULT_SUCCESS
            ip = upnp.query_external_address()
    call_deferred("_upnp_done", ok, ip)


func _upnp_done(ok: bool, ip: String) -> void:
    if _upnp_thread != null:
        _upnp_thread.wait_to_finish()
        _upnp_thread = null
    if ok:
        public_ip = ip
        _set_status("Porta aberta! Amigos de fora da sua rede entram em: %s" % ip)
    else:
        _set_status("UPnP indisponivel. Na rede local funciona normal; para a internet libere a porta %d (UDP) no roteador." % PORT)


# ------------------------------------------------------------ descoberta de salas (LAN / Wi-Fi / hotspot)
## Funciona assim (como o Mini Militia): o anfitriao anuncia a sala por broadcast e responde a
## "quem esta ai?". O cliente pergunta em cada sub-rede; se nada responder em 3 s, varre os IPs
## da rede (1..254) com pacotes pequenos. Isso cobre roteador, hotspot do celular e Wi-Fi Direct.
func _directed_broadcasts() -> Array:
    var out: Array = ["255.255.255.255"]
    for ip in local_ips():
        var p := str(ip).split(".")
        if p.size() == 4:
            var b := "%s.%s.%s.255" % [p[0], p[1], p[2]]
            if not out.has(b):
                out.append(b)
    return out


func _start_discovery(role: String) -> void:
    _stop_discovery()
    _sock = PacketPeerUDP.new()
    _sock.set_broadcast_enabled(true)
    var ok := _sock.bind(LAN_PORT) == OK
    if not ok and role == "client":
        for k in range(1, 8):          # outra instancia no mesmo aparelho: usa outra porta
            if _sock.bind(LAN_PORT + k) == OK:
                ok = true
                break
    if not ok:
        _sock = null
        return
    _role = role
    _bcast_t = 99.0
    _probe_t = 99.0
    _scan_t = 0.0
    _scan_queue.clear()
    if role == "client":
        lan_servers.clear()
    set_process(true)


func _stop_discovery() -> void:
    if _sock != null:
        _sock.close()
        _sock = null
    _role = ""
    _scan_queue.clear()


func start_lan_listen() -> void:
    _start_discovery("client")


func stop_lan_listen() -> void:
    if _role == "client":
        _stop_discovery()


func refresh_lan() -> void:
    if _role == "client":
        lan_servers.clear()
        lan_servers_changed.emit()
        _scan_t = 0.0
        _probe_t = 99.0


func _info_packet() -> PackedByteArray:
    var msg := JSON.stringify({"game": "polestar", "v": PROTOCOL, "name": Game.player_name,
            "track": str(lobby.get("track", "")), "players": players.size(), "max": MAX_PLAYERS, "in_race": in_race})
    return msg.to_utf8_buffer()


func _send_to(ip: String, port: int, data: PackedByteArray) -> void:
    if _sock == null:
        return
    _sock.set_dest_address(ip, port)
    _sock.put_packet(data)


func _process(delta: float) -> void:
    if _sock == null:
        # ping periodico do anfitriao durante a sala/corrida
        _tick_ping(delta)
        return
    if _role == "host" and multiplayer.multiplayer_peer != null:
        _bcast_t += delta
        if _bcast_t > 2.0:
            _bcast_t = 0.0
            for b in _directed_broadcasts():
                _send_to(b, LAN_PORT, _info_packet())
    elif _role == "client":
        _probe_t += delta
        _scan_t += delta
        if _probe_t > PROBE_EVERY:
            _probe_t = 0.0
            var q := JSON.stringify({"game": "polestar", "q": 1, "v": PROTOCOL}).to_utf8_buffer()
            for b in _directed_broadcasts():
                _send_to(b, LAN_PORT, q)
        # se o broadcast for bloqueado, varre a sub-rede (unicast)
        if lan_servers.is_empty() and _scan_t > 3.0 and _scan_queue.is_empty():
            _scan_t = 0.0
            for ip in local_ips():
                var p := str(ip).split(".")
                if p.size() == 4:
                    for h in range(1, 255):
                        var cand := "%s.%s.%s.%d" % [p[0], p[1], p[2], h]
                        if cand != str(ip):
                            _scan_queue.append(cand)
        if not _scan_queue.is_empty():
            var q2 := JSON.stringify({"game": "polestar", "q": 1, "v": PROTOCOL}).to_utf8_buffer()
            for _i in mini(40, _scan_queue.size()):
                _send_to(str(_scan_queue.pop_back()), LAN_PORT, q2)
    # recebe pacotes
    var changed := false
    while _sock != null and _sock.get_available_packet_count() > 0:
        var ip := _sock.get_packet_ip()
        var port := _sock.get_packet_port()
        var d = JSON.parse_string(_sock.get_packet().get_string_from_utf8())
        if not (d is Dictionary) or d.get("game", "") != "polestar":
            continue
        if _role == "host" and d.has("q"):
            _send_to(ip, port, _info_packet())          # responde a "quem esta ai?"
        elif _role == "client" and d.has("track"):
            lan_servers[ip] = {"name": d.get("name", "?"), "track": d.get("track", ""), "players": d.get("players", 1),
                    "max": d.get("max", MAX_PLAYERS), "v": int(d.get("v", 0)), "in_race": bool(d.get("in_race", false)),
                    "t": Time.get_ticks_msec()}
            changed = true
    if _role == "client":
        var now := Time.get_ticks_msec()
        for ip in lan_servers.keys():
            if now - int(lan_servers[ip]["t"]) > 5000:
                lan_servers.erase(ip)
                changed = true
    if changed:
        lan_servers_changed.emit()
    _tick_ping(delta)


func _tick_ping(delta: float) -> void:
    if not (multiplayer.multiplayer_peer is ENetMultiplayerPeer) or not multiplayer.is_server():
        return
    _ping_t += delta
    if _ping_t > 2.0:
        _ping_t = 0.0
        rpc("_cl_ping", Time.get_ticks_msec())
        if not in_race:
            _broadcast_players()
