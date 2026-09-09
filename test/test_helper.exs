# O envio de e-mail usa GMAIL_USER como remetente; define um fallback para os testes
System.put_env("GMAIL_USER", System.get_env("GMAIL_USER") || "prisma@example.com")

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(ProjetoPrisma.Repo, :manual)
