extends Node
## Vérifie sur GitHub s'il existe une version plus récente du jeu.
## Les versions sont publiées automatiquement (voir .github/workflows/apk.yml) :
## chaque version porte une étiquette « v0.3.2 » et le fichier APK en pièce jointe.

signal update_found(version: String, url: String)
signal check_done(found: bool, error: String)

const RELEASES_URL := "https://api.github.com/repos/louwnl/jeu-ferme/releases/latest"

var latest_version := ""
var download_url := ""
var _http: HTTPRequest


static func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


## Vrai si a est une version plus récente que b (« 0.10.0 » > « 0.9.3 »).
static func is_newer(a: String, b: String) -> bool:
	var pa := a.trim_prefix("v").split(".")
	var pb := b.trim_prefix("v").split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return x > y
	return false


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	_http.request_completed.connect(_on_completed)


func check() -> void:
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	var err := _http.request(RELEASES_URL, ["User-Agent: FermeRefuge", "Accept: application/vnd.github+json"])
	if err != OK:
		check_done.emit(false, "Impossible de vérifier les mises à jour.")


func open_download() -> void:
	if download_url != "":
		OS.shell_open(download_url)


func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		check_done.emit(false, "Pas de connexion internet.")
		return
	if code == 404:
		check_done.emit(false, "")  # aucune version publiée pour l'instant
		return
	if code != 200:
		check_done.emit(false, "GitHub ne répond pas (code %d)." % code)
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		check_done.emit(false, "Réponse de GitHub illisible.")
		return
	var tag := str(data.get("tag_name", ""))
	var url := ""
	for asset in data.get("assets", []):
		if str(asset.get("name", "")).ends_with(".apk"):
			url = str(asset.get("browser_download_url", ""))
	if url == "" or not is_newer(tag, current_version()):
		check_done.emit(false, "")
		return
	latest_version = tag.trim_prefix("v")
	download_url = url
	update_found.emit(latest_version, url)
	check_done.emit(true, "")
