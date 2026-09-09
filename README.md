# pa-project-prisma
N392-87 - PA2 | Projeto Prisma

Desenvolvimento<br>
03/03 a 12/03 - Sprint 01<br>
17/03 a 31/03 - Sprint 02<br>
07/04 a 16/04 - Sprint 03<br>
23/04 a 30/04 - Sprint 04<br>
05/05 a 14/05 - Sprint 05<br>
19/05 a 28/05 - Sprint 06<br>

---

## Requisitos

- [Docker](https://www.docker.com/) + [Docker Compose](https://docs.docker.com/compose/)

---

## Subindo o projeto

```bash
docker compose up --build
```

Acesse em: http://localhost:4000

---

## Parando o projeto

```bash
# Para os containers
docker compose down

# Para os containers e apaga os dados do banco
docker compose down -v
```

---

## Migrations

```bash
docker compose run --rm app mix ecto.migrate
```

---

## Acessar banco

```bash
docker compose exec db psql -U postgres
```

## Testes

```bash
# Rodar todos os testes
docker compose run --rm -e MIX_ENV=test app mix test

# Rodar um arquivo específico
docker compose run --rm -e MIX_ENV=test app mix test test/caminho/do_test.exs

# Rodar somente os testes que falharam anteriormente
docker compose run --rm -e MIX_ENV=test app mix test --failed

# Modo watch (TDD) — re-executa ao salvar arquivos
docker compose run --rm -e MIX_ENV=test app mix test.watch
```

> `mix test.watch` requer a dep `mix_test_watch`. Para instalar, adicione `{:mix_test_watch, "~> 1.0", only: :dev, runtime: false}` no `mix.exs` e rode `docker compose run --rm app mix deps.get`.

---

## API externa (app mobile)

A API JSON fica sob `/api` e usa **Bearer token**. O fluxo é: registrar (ou logar) → guardar o `token` retornado → enviar em todas as chamadas autenticadas no header `Authorization: Bearer <token>`.

### 1. Cadastro

```bash
curl -X POST http://localhost:4000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "username": "meu_user", "password": "senha123"}'
```

Resposta `201`:

```json
{
  "token": "YlWCnA-2MtC2hpCb...",
  "user": {"id": 1, "email": "user@example.com", "username": "meu_user", "full_name": null}
}
```

### 2. Login

```bash
curl -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "senha123"}'
```

Resposta `200` no mesmo formato do cadastro. Credenciais inválidas retornam `401`. Há rate limit de 10 tentativas a cada 5 minutos por IP+e-mail (`429`).

### 3. Usando o token

Guarde o `token` e envie no header `Authorization`:

```bash
TOKEN="cole-o-token-aqui"

# Dados do usuário, perfil e plataformas vinculadas
curl http://localhost:4000/api/auth/me \
  -H "Authorization: Bearer $TOKEN"
```

Sem token (ou com token inválido/expirado) os endpoints autenticados retornam `401 {"error": "Não autenticado"}`. O token expira em 30 dias.

### 4. Recuperar senha

```bash
# Solicita o e-mail de redefinição (resposta é 202 mesmo se o e-mail não existir)
curl -X POST http://localhost:4000/api/auth/password/forgot \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com"}'

# Redefine a senha usando o token recebido por e-mail
curl -X POST http://localhost:4000/api/auth/password/reset \
  -H "Content-Type: application/json" \
  -d '{"token": "TOKEN_DO_EMAIL", "password": "novaSenha123", "password_confirmation": "novaSenha123"}'
```

### 5. Vincular contas de plataforma (Steam/Xbox)

Steam e Xbox exigem login no navegador, então a API devolve uma URL para o app abrir (webview/navegador externo):

```bash
# Steam — precisa da Steam Web API Key do usuário
curl -X POST http://localhost:4000/api/platforms/steam/connect-url \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"api_key": "STEAM_WEB_API_KEY"}'

# Xbox — sem body
curl -X POST http://localhost:4000/api/platforms/xbox/connect-url \
  -H "Authorization: Bearer $TOKEN"
```

Resposta `200`: `{"url": "https://steamcommunity.com/openid/login?..."}`.

O app abre essa URL, o usuário autentica na plataforma e o callback redireciona para o deep link do app (padrão `prisma://connect?status=success&platform=steam`, configurável via env `MOBILE_DEEP_LINK`). Em caso de erro: `status=error&message=...`.

```bash
# Listar contas vinculadas
curl http://localhost:4000/api/platforms \
  -H "Authorization: Bearer $TOKEN"

# Desvincular
curl -X DELETE http://localhost:4000/api/platforms/steam \
  -H "Authorization: Bearer $TOKEN"
```

### 6. Logout (revoga o token)

```bash
curl -X POST http://localhost:4000/api/auth/logout \
  -H "Authorization: Bearer $TOKEN"
```

### Erros de validação

Erros de cadastro/validação retornam `422` com os campos:

```json
{"errors": {"email": ["has already been taken"], "password": ["deve ter no minimo 6 caracteres"]}}
```


