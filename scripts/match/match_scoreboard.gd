class_name MatchScoreboard
extends RefCounted

const KILL_POINTS: int = 3
const DEATH_PLANE_PENALTY: int = 3

var points: Dictionary = {}
var leaderboard: Label
var spawn_root: Node


func initialize(label: Label, player_root: Node) -> void:
	leaderboard = label
	spawn_root = player_root


func register_player(peer_id: int) -> void:
	if not points.has(peer_id):
		points[peer_id] = 0


func record_death(peer_id: int, attacker_id: int, from_death_plane: bool) -> void:
	if from_death_plane:
		points[peer_id] = points.get(peer_id, 0) - DEATH_PLANE_PENALTY
	elif attacker_id != peer_id and points.has(attacker_id):
		points[attacker_id] += KILL_POINTS


func refresh() -> void:
	if leaderboard == null:
		return

	var ranked_players: Array[Player] = []

	for child in spawn_root.get_children():
		if child is Player and not child.is_queued_for_deletion():
			ranked_players.append(child)

	ranked_players.sort_custom(_sort_by_points)

	var lines: PackedStringArray = PackedStringArray(["LEADERBOARD", ""])

	for index in range(ranked_players.size()):
		var player: Player = ranked_players[index]
		var peer_id: int = player.get_multiplayer_authority()
		var score: int = points.get(peer_id, 0)
		var display_name: String = player.player_username

		if display_name.is_empty() or display_name == "Unknown":
			display_name = "Player " + str(peer_id)

		display_name = display_name.replace("\n", " ").replace("\r", " ")

		lines.append("%d. %s — %d pts" % [index + 1, display_name, score])

	leaderboard.text = "\n".join(lines)


func _sort_by_points(a: Player, b: Player) -> bool:
	var a_id: int = a.get_multiplayer_authority()
	var b_id: int = b.get_multiplayer_authority()
	var a_score: int = points.get(a_id, 0)
	var b_score: int = points.get(b_id, 0)

	if a_score == b_score:
		return a_id < b_id

	return a_score > b_score
