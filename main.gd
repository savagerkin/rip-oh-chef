extends Node3D

const PLAYER_CONTROLLER = preload("uid://b5dxiciiiyot3")

var players: Array[CharacterBody3D]

@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("esc"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	Networking.host_created.connect(on_host_created)

	spawner.spawn_function = spawn_player


func on_host_created() -> void:
	# Server creates its own player.
	spawner.spawn(multiplayer.get_unique_id())

	# Server creates players for connecting clients.
	multiplayer.peer_connected.connect(on_peer_connected)
	multiplayer.peer_disconnected.connect(on_peer_disconnected)

#Remove the player when they disconnect
func on_peer_disconnected(peer_id: int) -> void:
	var player := get_node_or_null(str(peer_id))
	if player:
		player.queue_free()
	
func on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		spawner.spawn(peer_id)


func spawn_player(peer_id: Variant) -> Node:
	var player := PLAYER_CONTROLLER.instantiate() as CharacterBody3D

	player.name = str(peer_id)
	player.set_multiplayer_authority(int(peer_id))

	return player


func initialize_player(player: Player) -> void:
	player.position = $SpawnPoint.position
	# This removes the collison of others i think lol
	# for other in players:
	#	player.add_collision_exception_with(other)

	players.append(player)


func _on_multiplayer_spawner_spawned(node: Node) -> void:
	if node is Player:
		initialize_player(node)


func _on_host_pressed() -> void:
	$CanvasLayer.hide()
	Networking.host_lobby()


func _on_local_host_pressed() -> void:
	$CanvasLayer.hide()
	Networking.host_local()


func _on_local_join_pressed() -> void:
	$CanvasLayer.hide()
	Networking.join_local()
