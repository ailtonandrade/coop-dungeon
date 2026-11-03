extends Node
## Atualizador: confere no GitHub se saiu versão nova do jogo e avisa no menu. "Atualizar agora"
## baixa o pacote da plataforma (com progresso), confere o SHA-256 que o próprio GitHub calcula
## para o arquivo, extrai e deixa um script pequeno trocar os arquivos depois que o jogo fecha;
## aí o jogo abre de novo, já atualizado. Sem dar para atualizar sozinho (pasta sem permissão,
## navegador), o botão abre a página da versão para baixar à mão.
##
## Versões: a do jogo é application/config/version (project.godot); a do GitHub é a tag do
## release mais recente ("v0.2.0"). O release é feito por tools/lancar_release.bat.
##
## Rodando pelo editor do Godot (cópia de desenvolvimento) só avisa: atualize pelo Git.

signal changed

const REPO := "ailtonandrade/coop-dungeon"
const LATEST_URL := "https://api.github.com/repos/%s/releases/latest" % REPO
## Confere de novo de tempos em tempos (o limite da API do GitHub sem login é 60 por hora).
const CHECK_INTERVAL := 30.0 * 60.0
const WORK_DIR := "user://atualizacao"

enum Phase { IDLE, CHECKING, UP_TO_DATE, AVAILABLE, DOWNLOADING, INSTALLING, ERROR }

var phase := Phase.IDLE
var current := ""
var latest := ""
var notes := ""
var page_url := "https://github.com/%s/releases/latest" % REPO
var asset_url := ""
var asset_name := ""
var asset_size := 0
var asset_sha256 := ""
var error_text := ""
## O jogador clicou "Depois" nesta versão: o aviso grande não abre de novo (fica o selo no menu).
var dismissed := ""

## Para os testes: onde buscar o release e se finge estar no jogo exportado.
var latest_url := LATEST_URL
var force_exported := false

var _http: HTTPRequest
var _download: HTTPRequest
var _timer := 0.0


func _ready() -> void:
	current = version()
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	_http.request_completed.connect(_on_latest)
	add_child(_http)
	_download = HTTPRequest.new()
	_download.max_redirects = 10
	_download.request_completed.connect(_on_downloaded)
	add_child(_download)
	if not OS.has_feature("web") and DisplayServer.get_name() != "headless":
		check.call_deferred()


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= CHECK_INTERVAL and phase in [Phase.UP_TO_DATE, Phase.AVAILABLE, Phase.ERROR]:
		check()


## Versão deste jogo ("0.1.0").
static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


## -1, 0 ou 1, comparando número a número ("0.10.0" > "0.9.3"; "v" na frente é ignorado).
static func compare(a: String, b: String) -> int:
	var x := a.trim_prefix("v").split(".")
	var y := b.trim_prefix("v").split(".")
	for i in maxi(x.size(), y.size()):
		var d := (int(x[i]) if i < x.size() else 0) - (int(y[i]) if i < y.size() else 0)
		if d != 0:
			return signi(d)
	return 0


## Pacote desta plataforma no release, pelo fim do nome ("-Windows.zip", "-Linux.zip").
static func platform_suffix() -> String:
	if OS.has_feature("windows"):
		return "-Windows.zip"
	if OS.has_feature("linux"):
		return "-Linux.zip"
	return ""


func is_dev_copy() -> bool:
	return OS.has_feature("editor") and not force_exported


func has_update() -> bool:
	return not latest.is_empty() and compare(latest, current) > 0


## Dá para atualizar sozinho aqui (senão, só abrindo a página).
func can_self_update() -> bool:
	return has_update() and not is_dev_copy() and not asset_url.is_empty() and _game_dir_writable()


func progress() -> float:
	if phase != Phase.DOWNLOADING:
		return 1.0 if phase == Phase.INSTALLING else 0.0
	var total := _download.get_body_size()
	if total <= 0:
		total = asset_size
	return clampf(float(_download.get_downloaded_bytes()) / maxf(total, 1.0), 0.0, 1.0)


func check() -> void:
	if phase in [Phase.CHECKING, Phase.DOWNLOADING, Phase.INSTALLING]:
		return
	_timer = 0.0
	phase = Phase.CHECKING
	var headers := PackedStringArray(["Accept: application/vnd.github+json", "User-Agent: Corrumpted-jogo"])
	if _http.request(latest_url, headers) != OK:
		_fail("Não deu para procurar versão nova.")


func _on_latest(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		# Sem internet ou sem release ainda: tenta de novo mais tarde, sem incomodar.
		phase = Phase.UP_TO_DATE if latest.is_empty() else Phase.AVAILABLE
		changed.emit()
		return
	apply_release(JSON.parse_string(body.get_string_from_utf8()))


## Lê o release do GitHub (o JSON de /releases/latest).
func apply_release(data: Variant) -> void:
	if not data is Dictionary or not data.has("tag_name"):
		phase = Phase.UP_TO_DATE
		changed.emit()
		return
	latest = String(data.tag_name).trim_prefix("v")
	notes = String(data.get("body", ""))
	page_url = String(data.get("html_url", page_url))
	asset_url = ""
	asset_name = ""
	asset_sha256 = ""
	asset_size = 0
	var suffix := platform_suffix()
	for asset: Variant in data.get("assets", []):
		if asset is Dictionary and not suffix.is_empty() and String(asset.get("name", "")).ends_with(suffix):
			asset_url = String(asset.get("browser_download_url", ""))
			asset_name = String(asset.name)
			asset_size = int(asset.get("size", 0))
			asset_sha256 = String(asset.get("digest", "")).trim_prefix("sha256:")
	phase = Phase.AVAILABLE if has_update() else Phase.UP_TO_DATE
	changed.emit()


## "Atualizar agora": baixa, confere, extrai e reinicia atualizado.
func start_update() -> void:
	if not can_self_update():
		open_page()
		return
	if phase in [Phase.DOWNLOADING, Phase.INSTALLING]:
		return
	DirAccess.make_dir_recursive_absolute(WORK_DIR)
	_download.download_file = WORK_DIR.path_join(asset_name)
	phase = Phase.DOWNLOADING
	error_text = ""
	changed.emit()
	if _download.request(asset_url, PackedStringArray(["User-Agent: Corrumpted-jogo"])) != OK:
		_fail("Não deu para começar a baixar.")


func open_page() -> void:
	OS.shell_open(page_url)


func _on_downloaded(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail(Txt.t("A internet caiu no meio do download (código %d). Tente de novo.") % code)
		return
	install_from(_download.download_file)


## Confere o pacote baixado, extrai e chama o script que troca os arquivos com o jogo fechado.
func install_from(zip_path: String) -> bool:
	phase = Phase.INSTALLING
	changed.emit()
	if not asset_sha256.is_empty() and file_sha256(zip_path) != asset_sha256:
		_fail("O arquivo baixado não confere com o do GitHub. Tente de novo.")
		return false
	var target := WORK_DIR.path_join("novo")
	if not extract(zip_path, target):
		_fail("Não deu para abrir o pacote baixado.")
		return false
	var script := write_swap_script(ProjectSettings.globalize_path(target), game_dir(), OS.get_process_id())
	if script.is_empty():
		_fail("Não deu para preparar a atualização.")
		return false
	if Engine.has_meta("updater_no_restart"):
		return true
	if OS.has_feature("windows"):
		OS.create_process("cmd.exe", ["/c", script])
	else:
		OS.create_process("/bin/sh", [script])
	get_tree().quit()
	return true


static func file_sha256(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	while file.get_position() < file.get_length():
		hashing.update(file.get_buffer(1 << 20))
	return hashing.finish().hex_encode()


## Extrai o .zip inteiro para `target` (apaga o que tinha lá antes).
static func extract(zip_path: String, target: String) -> bool:
	var zip := ZIPReader.new()
	if zip.open(zip_path) != OK:
		return false
	_remove_dir(target)
	DirAccess.make_dir_recursive_absolute(target)
	for entry in zip.get_files():
		if entry.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(target.path_join(entry))
			continue
		if entry.contains(".."):
			continue
		DirAccess.make_dir_recursive_absolute(target.path_join(entry).get_base_dir())
		var out := FileAccess.open(target.path_join(entry), FileAccess.WRITE)
		if out == null:
			zip.close()
			return false
		out.store_buffer(zip.read_file(entry))
		out.close()
	zip.close()
	return true


static func _remove_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove_dir(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


## Pasta do jogo instalado (onde está o executável).
static func game_dir() -> String:
	return OS.get_executable_path().get_base_dir()


## Script que espera o jogo fechar, copia os arquivos novos por cima e abre o jogo de novo.
## Retorna o caminho dele ("" se não deu para gravar).
func write_swap_script(new_dir: String, dir: String, pid: int, windows := OS.has_feature("windows")) -> String:
	var exe := OS.get_executable_path().get_file()
	var path := ProjectSettings.globalize_path(WORK_DIR.path_join("atualizar.bat" if windows else "atualizar.sh"))
	var text := ""
	if windows:
		text = "\r\n".join([
			"@echo off",
			"chcp 65001 >nul",
			"title Atualizando o Corrumpted",
			"echo Atualizando o Corrumpted para a versao %s..." % latest,
			":espera",
			"tasklist /FI \"PID eq %d\" 2>nul | find \"%d\" >nul && (timeout /t 1 /nobreak >nul & goto espera)" % [pid, pid],
			"robocopy \"%s\" \"%s\" /E /R:10 /W:1 /NFL /NDL /NJH /NJS /NP >nul" % [new_dir.replace("/", "\\"), dir.replace("/", "\\")],
			"start \"\" \"%s\"" % dir.path_join(exe).replace("/", "\\"),
			"",
		])
	else:
		text = "\n".join([
			"#!/bin/sh",
			"while kill -0 %d 2>/dev/null; do sleep 1; done" % pid,
			"cp -rf \"%s\"/. \"%s\"/" % [new_dir, dir],
			"chmod +x \"%s\"" % dir.path_join(exe),
			"\"%s\" &" % dir.path_join(exe),
			"",
		])
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(text)
	file.close()
	return path


## Dá para gravar na pasta do jogo? (Instalado em Arquivos de Programas, por exemplo, não dá.)
func _game_dir_writable() -> bool:
	var probe := game_dir().path_join(".teste_atualizacao")
	var file := FileAccess.open(probe, FileAccess.WRITE)
	if file == null:
		return false
	file.close()
	DirAccess.remove_absolute(probe)
	return true


func _fail(text: String) -> void:
	error_text = text
	phase = Phase.ERROR
	changed.emit()
