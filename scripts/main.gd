extends Node3D

const PLAYER_CONTROLLER = preload("uid://b5dxiciiiyot3")

var players: Array[CharacterBody3D]

@export var spawner: MultiplayerSpawner 
@export var canvasLayer: CanvasLayer 
@export var spawnPoint: Node3D

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("esc"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

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
	canvasLayer.hide()
	
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
	spawner.spawn({
		"peer_id": peer_id,
		"steam_id": steam_id
	})


func spawn_player(data: Variant) -> Node:
	var player := PLAYER_CONTROLLER.instantiate() as Player

	var peer_id: int = data["peer_id"]
	var steam_id: int = data["steam_id"]

	player.name = str(peer_id)
	player.set_multiplayer_authority(peer_id)

	player.steam_id = steam_id

	return player


func initialize_player(player: Player) -> void:
	player.position = spawnPoint.position
	
	# This removes the collison of others i think lol
	# for other in players:
	#	player.add_collision_exception_with(other)

	players.append(player)


func _on_multiplayer_spawner_spawned(node: Node) -> void:
	if node is Player:
		initialize_player(node)


func _on_host_pressed() -> void:
	canvasLayer.hide()
	Networking.host_lobby()


func _on_local_host_pressed() -> void:
	canvasLayer.hide()
	Networking.host_local()


func _on_local_join_pressed() -> void:
	canvasLayer.hide()
	Networking.join_local()
