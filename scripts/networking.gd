extends Node

signal host_created()
signal joined_game()

signal steam_identity_received(peer_id: int, steam_id: int)

const LOBBY_TYPE := Steam.LobbyType.LOBBY_TYPE_FRIENDS_ONLY
const MAX_MEMBERS: int = 4

const LOCAL_PORT: int = 7777

var peer: MultiplayerPeer


func _ready() -> void:
	Steam.initRelayNetworkAccess()
	Steam.lobby_created.connect(on_lobby_created)
	Steam.lobby_joined.connect(on_lobby_joined)
	Steam.join_requested.connect(on_join_requested)

	multiplayer.connected_to_server.connect(on_connected_to_server)


func _process(_delta: float) -> void:
	Steam.run_callbacks()


# STEAM
func host_lobby() -> void:
	Steam.createLobby(LOBBY_TYPE, MAX_MEMBERS)


func on_lobby_created(result: int, _lobby_id: int) -> void:
	if result != Steam.RESULT_OK:
		return

	var steam_peer: SteamMultiplayerPeer = SteamMultiplayerPeer.new()
	steam_peer.server_relay = true
	steam_peer.create_host()

	set_peer(steam_peer)

	host_created.emit()


func on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		return

	if Steam.getLobbyOwner(lobby_id) == Steam.getSteamID():
		return

	var steam_peer: SteamMultiplayerPeer = SteamMultiplayerPeer.new()
	steam_peer.server_relay = true
	steam_peer.create_client(Steam.getLobbyOwner(lobby_id))

	set_peer(steam_peer)
	joined_game.emit()


func on_join_requested(lobby_id: int, _steam_id: int) -> void:
	Steam.joinLobby(lobby_id)


# Called on a client when it successfully connects to the server.
func on_connected_to_server() -> void:
	if multiplayer.multiplayer_peer is not SteamMultiplayerPeer:
		return

	send_steam_identity.rpc_id(1, Steam.getSteamID())


# Sends this client's Steam ID to the server.
@rpc("any_peer", "call_remote", "reliable")
func send_steam_identity(steam_id: int) -> void:
	if not multiplayer.is_server():
		return

	var peer_id: int = multiplayer.get_remote_sender_id()

	steam_identity_received.emit(peer_id, steam_id)


# Gets a Steam username from a Steam ID.
func get_username_from_steam_id(steam_id: int) -> String:
	if steam_id <= 0:
		return "Unknown"

	# Our own Steam account.
	if steam_id == Steam.getSteamID():
		return Steam.getPersonaName()

	# Other Steam player.
	var steam_username: String = Steam.getFriendPersonaName(steam_id)

	if steam_username.is_empty():
		# Ask Steam to cache their persona information.
		Steam.requestUserInformation(steam_id, false)

		return "Unknown"

	return steam_username


# LOCAL TESTING
func host_local() -> void:
	var local_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()

	var error: Error = local_peer.create_server(LOCAL_PORT, MAX_MEMBERS)

	if error != OK:
		print("Failed to create local server: ", error)
		return

	set_peer(local_peer)

	print("Local server started")
	host_created.emit()


func join_local() -> void:
	var local_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()

	var error: Error = local_peer.create_client("127.0.0.1", LOCAL_PORT)

	if error != OK:
		print("Failed to join local server: ", error)
		return

	set_peer(local_peer)

	print("Joining local server...")


func set_peer(new_peer: MultiplayerPeer) -> void:
	peer = new_peer
	multiplayer.multiplayer_peer = peer
