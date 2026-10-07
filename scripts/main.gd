extends Node3D

const PLAYER_CONTROLLER = preload("uid://b5dxiciiiyot3")

var players: Array[CharacterBody3D]

@export var spawner: MultiplayerSpawner
@export var canvas_layer: CanvasLayer
@export var spawn_points: Node3D
@export var leaderboard: Label

var leaderboard_refresh: float = 0.0
var points: Dictionary = {}

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("esc"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	leaderboard_refresh += delta

	if leaderboard_refresh >= 0.25:
		leaderboard_refresh = 0.0
		update_leaderboard()
	
func _ready() -> void:
	Networking.host_created.connect(on_host_created)
	Networking.steam_identity_received.connect(on_steam_identity_received)
	Networking.joined_game.connect(on_joined_game)

	spawner.spawn_function = spawn_player


func on_host_created() -> void:
	# Server creates its own player.
	if multiplayer.multiplayer_peer is SteamMultiplayerPeer:
		spawn_network_player(
			multiplayer.get_unique_id(),
			Steam.getSteamID()
		)
	else:
		spawn_network_player(
			multiplayer.get_unique_id(),
			0
		)

	# Server creates players for connecting clients.
	multiplayer.peer_connected.connect(on_peer_connected)
	multiplayer.peer_disconnected.connect(on_peer_disconnected)

# Called when someone joins the game
func on_joined_game() -> void:
	canvas_layer.hide()

#Remove the player when they disconnect
func on_peer_disconnected(peer_id: int) -> void:
	var player := get_node_or_null(str(peer_id))
	if player:
		player.queue_free()


func on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	# To hide the canvas when joining.
	# Steam clients will send us their Steam ID,
	# so don't spawn them yet.
	if multiplayer.multiplayer_peer is SteamMultiplayerPeer:
		return

	# Local ENet testing
	spawn_network_player(peer_id, 0)


# Called when a Steam client tells us their Steam ID.
func on_steam_identity_received(peer_id: int, steam_id: int) -> void:
	if not multiplayer.is_server():
		return

	spawn_network_player(peer_id, steam_id)

func spawn_network_player(peer_id: int, steam_id: int) -> void:
	if not multiplayer.is_server():
		return

	var points: Array[Node3D] = []

	for child in spawn_points.get_children():
		if child is Node3D:
			points.append(child)

	if points.is_empty():
		push_error("No spawn points assigned")
		return

	var point: Node3D = points.pick_random()
	var spawn_root := spawner.get_node(spawner.spawn_path) as Node3D

	var player := spawner.spawn({
		"peer_id": peer_id,
		"steam_id": steam_id,
		"position": spawn_root.to_local(point.global_position)
	}) as Player

	if player:
		initialize_player(player)


func spawn_player(data: Variant) -> Node:
	var player := PLAYER_CONTROLLER.instantiate() as Player

	var peer_id: int = data["peer_id"]
	var steam_id: int = data["steam_id"]

	player.name = str(peer_id)
	player.set_multiplayer_authority(peer_id)
	player.steam_id = steam_id
	player.position = data["position"]

	return player


func initialize_player(player: Player) -> void:
	if not players.has(player):
		players.append(player)
		player.died.connect(on_player_died)

	if multiplayer.is_server():
		var peer_id := player.get_multiplayer_authority()

		if not points.has(peer_id):
			points[peer_id] = 0

		sync_points.rpc(points)

@rpc("authority", "call_remote", "reliable")
func sync_points(updated_points: Dictionary) -> void:
	points = updated_points.duplicate()

func _on_multiplayer_spawner_spawned(node: Node) -> void:
	if node is Player:
		initialize_player(node)


func _on_host_pressed() -> void:
	canvas_layer.hide()
	Networking.host_lobby()


func _on_local_host_pressed() -> void:
	canvas_layer.hide()
	Networking.host_local()


func _on_local_join_pressed() -> void:
	canvas_layer.hide()
	Networking.join_local()

func on_player_died(player: Player) -> void:
	request_respawn.rpc_id(
		1,
		player.last_attacker_id,
		player.died_to_death_plane
	)


@rpc("any_peer", "call_local", "reliable")
func request_respawn(
	attacker_id: int = 0,
	from_death_plane: bool = false
) -> void:
	if not multiplayer.is_server():
		return

	var peer_id := multiplayer.get_remote_sender_id()
	var spawn_root := spawner.get_node(spawner.spawn_path)
	var player := spawn_root.get_node_or_null(str(peer_id)) as Player

	if player == null or player.get_multiplayer_authority() != peer_id:
		return

	var available_points: Array[Node3D] = []

	for child in spawn_points.get_children():
		if child is Node3D:
			available_points.append(child)

	if available_points.is_empty():
		push_error("No spawn points assigned")
		return

	if from_death_plane:
		points[peer_id] = points.get(peer_id, 0) - 3
	elif attacker_id != peer_id and points.has(attacker_id):
		points[attacker_id] += 3

	sync_points.rpc(points)
	print("Points: ", points)

	var point: Node3D = available_points.pick_random()

	if player.is_multiplayer_authority():
		player.respawn_at(point.global_position)
	else:
		player.respawn_at.rpc_id(peer_id, point.global_position)

func update_leaderboard() -> void:
	if leaderboard == null:
		return

	var ranked_players: Array[Player] = []
	var spawn_root := spawner.get_node(spawner.spawn_path)

	for child in spawn_root.get_children():
		if child is Player and not child.is_queued_for_deletion():
			ranked_players.append(child)

	ranked_players.sort_custom(_sort_by_points)

	var lines := PackedStringArray(["LEADERBOARD", ""])

	for index in range(ranked_players.size()):
		var player := ranked_players[index]
		var peer_id := player.get_multiplayer_authority()
		var score: int = points.get(peer_id, 0)
		var display_name := player.player_username

		if display_name.is_empty() or display_name == "Unknown":
			display_name = "Player " + str(peer_id)

		display_name = display_name.replace("\n", " ").replace("\r", " ")

		lines.append(
			"%d. %s — %d pts"
			% [index + 1, display_name, score]
		)

	leaderboard.text = "\n".join(lines)


func _sort_by_points(a: Player, b: Player) -> bool:
	var a_id := a.get_multiplayer_authority()
	var b_id := b.get_multiplayer_authority()
	var a_score: int = points.get(a_id, 0)
	var b_score: int = points.get(b_id, 0)

	if a_score == b_score:
		return a_id < b_id

	return a_score > b_score
	
