extends Node
## Identidade do jogador por plataforma.
## Protótipo: perfis locais por slot.
## Xbox / Microsoft Store: um usuário Xbox por controle (XUser do GDK).
## Steam: login com a conta Microsoft, para o mesmo save valer nas duas lojas.


func get_profile_id(slot: int) -> String:
	return "local_p%d" % (slot + 1)


func get_host_profile_id() -> String:
	return get_profile_id(0)
