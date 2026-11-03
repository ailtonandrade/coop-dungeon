extends SceneTree
## Atualizador: comparar versões, ler o release do GitHub, e o caminho inteiro com um servidor
## falso no lugar do GitHub (acha a versão nova, baixa, confere o SHA-256, extrai e prepara o
## script que troca os arquivos). Também recusa arquivo que não confere.
## Rodar: godot --headless --fixed-fps 60 --path coop-dungeon -s tests/updater_test.gd
## Sem tipos do jogo aqui: o script de teste compila antes dos serviços globais existirem.

const PORT := 18765

var _failed := false
var _server := TCPServer.new()
var _files := {}  # caminho -> PackedByteArray
var _clients: Array[StreamPeerTCP] = []
var _step := 0
var _wait := 0
var _updater: Node
var _zip_sha := ""


func _initialize() -> void:
	var u: Script = load("res://core/updater.gd")
	_check(u.compare("0.10.0", "0.9.3") == 1, "0.10.0 é mais nova que 0.9.3")
	_check(u.compare("v1.2.0", "1.2") == 0, "v1.2.0 é igual a 1.2")
	_check(u.compare("0.1.0", "0.1.1") == -1, "0.1.0 é mais velha que 0.1.1")


func _process(_delta: float) -> bool:
	_serve()
	match _step:
		0:
			_updater = root.get_node("Updater")
			_updater.current = "0.1.0"
			_updater.force_exported = true
			Engine.set_meta("updater_no_restart", true)
			# Pacote "novo": dois arquivos, como o .zip do release.
			var zip_path := "user://teste_pacote.zip"
			var packer := ZIPPacker.new()
			packer.open(zip_path)
			for entry: Array in [["Corrumpted.pck", "pck novo"], ["leia.txt", "versao 0.2.0"]]:
				packer.start_file(entry[0])
				packer.write_file(String(entry[1]).to_utf8_buffer())
				packer.close_file()
			packer.close()
			_files["/pacote.zip"] = FileAccess.get_file_as_bytes(zip_path)
			_zip_sha = _updater.file_sha256(zip_path)
			var suffix: String = _updater.platform_suffix()
			_files["/release.json"] = JSON.stringify({
				"tag_name": "v0.2.0", "html_url": "http://127.0.0.1:%d/pagina" % PORT,
				"body": "**Como jogar**\n- coisa", "assets": [
					{"name": "Corrumpted-v0.2.0" + suffix, "size": _files["/pacote.zip"].size(),
					"digest": "sha256:" + _zip_sha, "browser_download_url": "http://127.0.0.1:%d/pacote.zip" % PORT},
					{"name": "Corrumpted-v0.2.0-Web.zip", "size": 1, "browser_download_url": "http://127.0.0.1:%d/web.zip" % PORT},
				]}).to_utf8_buffer()
			_check(_server.listen(PORT, "127.0.0.1") == OK, "servidor falso do GitHub no ar")
			_updater.latest_url = "http://127.0.0.1:%d/release.json" % PORT
			_updater.check()
			_step = 1
		1:
			if _updater.phase != _updater.Phase.CHECKING:
				_check(_updater.has_update() and _updater.latest == "0.2.0", "achou a versão nova 0.2.0 (estou na 0.1.0)")
				_check(_updater.asset_url.ends_with("/pacote.zip") and _updater.asset_sha256 == _zip_sha, "escolheu o pacote desta plataforma, com o SHA-256 do GitHub")
				_check(_updater.can_self_update(), "dá para atualizar sozinho")
				_updater.start_update()
				_step = 2
		2:
			if _updater.phase in [_updater.Phase.INSTALLING, _updater.Phase.ERROR] and not _updater.error_text.is_empty() or _wait > 600:
				_step = 3
			elif _updater.phase == _updater.Phase.INSTALLING and FileAccess.file_exists("user://atualizacao/novo/leia.txt"):
				_step = 3
			_wait += 1
		3:
			_check(_updater.error_text.is_empty(), "baixou e conferiu sem erro (%s)" % _updater.error_text)
			_check(FileAccess.get_file_as_string("user://atualizacao/novo/leia.txt") == "versao 0.2.0", "extraiu o pacote novo")
			var script_name := "atualizar.bat" if OS.has_feature("windows") else "atualizar.sh"
			var script := FileAccess.get_file_as_string("user://atualizacao/" + script_name)
			_check(script.contains(str(OS.get_process_id())) and script.contains(ProjectSettings.globalize_path("user://atualizacao/novo")),
					"preparou o script que espera o jogo fechar e copia os arquivos novos")
			var win: String = FileAccess.get_file_as_string(_updater.write_swap_script("C:/novo", "C:/Jogos/Corrumpted", 4242, true))
			_check(win.contains("PID eq 4242") and win.contains("robocopy \"C:\\novo\" \"C:\\Jogos\\Corrumpted\"") and win.contains("start \"\""),
					"no Windows: espera o jogo fechar, copia com robocopy e abre de novo")
			# Arquivo adulterado: não instala.
			_updater.asset_sha256 = "0".repeat(64)
			_updater.install_from(_updater.WORK_DIR.path_join(_updater.asset_name))
			_check(_updater.phase == _updater.Phase.ERROR and _updater.error_text.contains("não confere"), "arquivo que não confere com o GitHub é recusado")
			# Sem versão nova: nada a fazer.
			_updater.apply_release({"tag_name": "v0.1.0", "assets": []})
			_check(not _updater.has_update(), "release igual ao meu: sem aviso")
			_updater.force_exported = false
			_check(_updater.is_dev_copy() and not _updater.can_self_update(), "rodando pelo editor: só avisa (atualizar pelo Git)")
			_server.stop()
			print("ATUALIZADOR: " + ("FALHOU" if _failed else "OK"))
			quit(1 if _failed else 0)
	return false


## Servidor HTTP mínimo: responde GET com o arquivo pedido.
func _serve() -> void:
	if not _server.is_listening():
		return
	while _server.is_connection_available():
		_clients.append(_server.take_connection())
	for client in _clients.duplicate():
		client.poll()
		if client.get_available_bytes() <= 0:
			if client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
				_clients.erase(client)
			continue
		var request: String = client.get_utf8_string(client.get_available_bytes())
		var path: String = request.split(" ")[1] if request.split(" ").size() > 1 else "/"
		var body: PackedByteArray = _files.get(path, "nada".to_utf8_buffer())
		var status := "200 OK" if _files.has(path) else "404 Not Found"
		client.put_data(("HTTP/1.1 %s\r\nContent-Length: %d\r\nContent-Type: application/octet-stream\r\nConnection: close\r\n\r\n" % [status, body.size()]).to_utf8_buffer())
		client.put_data(body)
		client.disconnect_from_host()
		_clients.erase(client)


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	_failed = _failed or not ok
