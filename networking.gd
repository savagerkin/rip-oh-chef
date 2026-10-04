extends Node

signal host_created()

const LOBBY_TYPE := Steam.LobbyType.LOBBY_TYPE_FRIENDS_ONLY
const MAX_MEMBERS := 4

const LOCAL_PORT := 7777

var peer: MultiplayerPeer


func _ready() -> void:
	Steam.initRelayNetworkAccess()
	Steam.lobby_created.connect(on_lobby_created)
	Steam.lobby_joined.connect(on_lobby_joined)
	Steam.join_requested.connect(on_join_requested)

func _process(_delta: float) -> void:
	Steam.run_callbacks()

# STEAM

func host_lobby() -> void:
	Steam.createLobby(LOBBY_TYPE, MAX_MEMBERS)


func on_lobby_created(result: int, _lobby_id: int) -> void:
	if result == Steam.RESULT_OK:
		var steam_peer := SteamMultiplayerPeer.new()
		steam_peer.server_relay = true
		steam_peer.create_host()

		peer = steam_peer
		multiplayer.multiplayer_peer = peer

		host_created.emit()


func on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		if Steam.getLobbyOwner(lobby_id) == Steam.getSteamID():
			return

		var steam_peer := SteamMultiplayerPeer.new()
		steam_peer.server_relay = true
		steam_peer.create_client(Steam.getLobbyOwner(lobby_id))

		peer = steam_peer
		multiplayer.multiplayer_peer = peer


func on_join_requested(lobby_id: int, _steam_id: int) -> void:
	Steam.joinLobby(lobby_id)

func get_username(peer_id: int) -> String:
	# Local ENet testing
	if multiplayer.multiplayer_peer is not SteamMultiplayerPeer:
		return "Player " + str(peer_id)

	# If this is OUR player, Steam already knows our username.
	if peer_id == multiplayer.get_unique_id():
		return Steam.getPersonaName()

	# Otherwise find the Steam ID belonging to the remote peer.
	var steam_peer := multiplayer.multiplayer_peer as SteamMultiplayerPeer

	var steam_id: int = steam_peer.get_steam64_from_peer_id(peer_id)

	if steam_id <= 0:
		return "Unknown"

	return Steam.getFriendPersonaName(steam_id)

# LOCAL TESTING

func host_local() -> void:
	var local_peer := ENetMultiplayerPeer.new()

	var error := local_peer.create_server(LOCAL_PORT, MAX_MEMBERS)

	if error != OK:
		print("Failed to create local server: ", error)
		return

	peer = local_peer
	multiplayer.multiplayer_peer = peer

	print("Local server started")
	host_created.emit()


func join_local() -> void:
	var local_peer := ENetMultiplayerPeer.new()

	var error := local_peer.create_client("127.0.0.1", LOCAL_PORT)

	if error != OK:
		print("Failed to join local server: ", error)
		return

	peer = local_peer
	multiplayer.multiplayer_peer = peer

	print("Joining local server...")
	
	
