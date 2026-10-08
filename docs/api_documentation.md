# Projeto de API

O sistema Prisma adota uma **arquitetura monolítica com frontend e backend unificados** para a interface web, e expõe uma **API REST JSON sob `/api`** destinada a clientes externos (ex.: aplicativo mobile).

---

## Interface web (LiveView)

A aplicação web é **server-rendered** com **Phoenix LiveView**: toda a lógica de apresentação roda no servidor e o navegador recebe HTML atualizado via **WebSockets** — sem chamadas HTTP a uma API. O LiveView elimina a necessidade de endpoints JSON para o próprio frontend, serialização duplicada e manutenção de contratos entre camadas.

A tabela abaixo resume como cada tipo de interação é tratado na interface web:

| Tipo de interação | Tecnologia utilizada | Descrição |
|-------------------|---------------------|-----------|
| Renderização de páginas | Phoenix LiveView | HTML gerado no servidor e enviado ao navegador |
| Atualizações em tempo real | WebSocket (via LiveView) | Diffs de HTML enviados automaticamente |
| Eventos de usuário | LiveView events (`phx-click`, etc.) | Disparam funções no servidor sem recarregar a página |
| Autenticação | Sessão HTTP + Plug | Tokens e cookies gerenciados pelo Phoenix |
| Integrações externas | HTTP clients (Req) | Comunicação com APIs de jogos (Steam, Xbox, etc.) |

---

## API REST (`/api`) — clientes externos (mobile)

A pipeline `:api` (antes reservada) agora expõe endpoints JSON para autenticação e vinculação de contas de plataforma, pensados para um app mobile.

### Autenticação

A API usa **Bearer tokens opacos** persistidos na tabela `users_tokens` (contexto `"api"`), o que permite revogação individual (logout) sem dependências externas (sem JWT/guardian).

- Validade padrão: **30 dias** (`config :projeto_prisma, :api_token_validity_days`).
- Envio: header `Authorization: Bearer <token>`.
- Respostas de erro seguem o formato `{"error": "mensagem"}` ou `{"errors": {"campo": ["mensagem"]}}` (422).

### Endpoints públicos

| Método | Rota | Body | Resposta |
|--------|------|------|----------|
| POST | `/api/auth/register/code` | `{email, password, username, full_name?}` | `202 {verification_token, expires_in, resend_in}` / `422` erros de validação / `429` (5 envios/10 min por e-mail) / `503` falha no envio |
| POST | `/api/auth/register` | `{email, password, username, full_name?, code, verification_token}` | `201 {token, user}` / `400` sem código ou token inválido / `410` código expirado / `422` código incorreto ou erros de validação / `429` (5 tentativas por código) |
| POST | `/api/auth/availability` | `{username?, email?}` | `200 {username?: bool, email?: bool}` (`true` = disponível) / `400` sem campos / `429` (30/5 min por IP) |
| POST | `/api/auth/login` | `{email, password}` | `200 {token, user}` / `401` / `429` (rate limit: 10 tentativas/5 min por IP+e-mail) |
| POST | `/api/auth/password/forgot` | `{email}` | `202 {message}` (resposta idêntica exista ou não a conta; rate limit 5/5 min) |
| POST | `/api/auth/password/reset` | `{token, password, password_confirmation}` | `200 {message}` / `400` token inválido / `422` |

### Endpoints autenticados (`Authorization: Bearer`)

| Método | Rota | Descrição |
|--------|------|-----------|
| GET | `/api/auth/me` | `{user, profile, platforms}` do usuário autenticado |
| POST | `/api/auth/logout` | Revoga o token atual (`204`) |
| DELETE | `/api/auth/account` | Deleta a conta, profile e todas as plataformas vinculadas (`204`) |
| GET | `/api/platforms` | Lista contas vinculadas: `[{platform, external_user_id, profile_url, sync_status}]` |
| POST | `/api/platforms/steam/connect-url` | Body `{api_key}` → `{url}` (OpenID da Steam) |
| POST | `/api/platforms/xbox/connect-url` | → `{url}` (authorize da Microsoft) |
| POST | `/api/platforms/:slug/verification-code` | PSN/RetroAchievements → `{code, verification_token, expires_in}` |
| POST | `/api/platforms/:slug/connect` | PSN/RetroAchievements. Body `{username, api_key, verification_token}` → `{platform}` / `410` código expirado / `422 {error, reason}` |
| DELETE | `/api/platforms/:slug` | Desvincula a conta (`204` / `404` / `409` sync em andamento) |

### Fluxo de cadastro com confirmação de e-mail no mobile

A conta só é criada depois que o usuário confirma o e-mail com um código de 6 dígitos, com as mesmas regras do cadastro web (validade de 10 min, 5 tentativas, reenvio após 60 s):

1. O app envia os dados do cadastro para `POST /api/auth/register/code`. A API valida tudo (inclusive e-mail e username em uso) e só então envia o código por e-mail.
2. A resposta traz um `verification_token`: o código criptografado junto do e-mail (`Phoenix.Token.encrypt`, válido por 10 min). O servidor não guarda estado, e o app não consegue ler o código de dentro do token.
3. O app reenvia os mesmos dados para `POST /api/auth/register`, acrescentando `code` e `verification_token`. A conta é criada já confirmada (`confirmed_at`) e a resposta é a mesma do login.
4. Para reenviar o código, o app repete o passo 1 e passa a usar o novo token.

### Fluxo de vinculação de plataformas (Steam/Xbox) no mobile

Como Steam (OpenID) e Xbox (OAuth2) exigem navegador, o fluxo é:

1. O app chama `POST /api/platforms/:slug/connect-url` autenticado.
2. A API retorna uma URL de autorização cujo `state` é um `Phoenix.Token` assinado (válido por 10 min) contendo o `profile_id` — e, no caso da Steam, a `api_key` do usuário.
3. O app abre a URL no navegador/webview; o usuário autentica na plataforma.
4. O callback (`/auth/:platform/callback`) identifica o perfil pelo `state` assinado (não pela sessão), vincula a conta e redireciona para o **deep link** configurado em `:mobile_deep_link` (padrão `prisma://connect`) com `?status=success|error&platform=...&message=...`.

As mesmas rotas de callback atendem o fluxo web (sessão + flash redirect para `/connect-platforms`) — o `state` define qual fluxo está em curso.

### Fluxo de vinculação de PSN e RetroAchievements no mobile

Essas plataformas não têm OAuth, e credenciais válidas não provam que a conta informada é do usuário (qualquer NPSSO/API Key consulta qualquer perfil). A posse é provada por um código no perfil:

1. O app chama `POST /api/platforms/:slug/verification-code` e exibe o `code` (`PRISMA-XXXX`).
2. O usuário cola o código no "Sobre Mim" (PSN) ou no "Motto" (RetroAchievements).
3. O app envia `POST /api/platforms/:slug/connect` com `username` (PSN ID / usuário RA), `api_key` (NPSSO / Web API Key) e o `verification_token` recebido. O token é um `Phoenix.Token` assinado com `profile_id`, plataforma e código (válido por 30 min), então o servidor não guarda estado.
4. A API valida as credenciais, busca o perfil, confere o código e vincula a conta. `reason` no `422`: `verification_code_missing`, `invalid_credentials`, `account_not_found`, `request_failed`, `http_status`, `platform_not_found`, `missing_fields`.

### Observações

- **CORS** vale só para `/api` e só para as origens de `config :projeto_prisma, :cors_origins` (`ProjetoPrismaWeb.Plugs.Cors`). Em dev a lista libera o app web do Expo em `http://localhost:8081`; em outros ambientes, defina `CORS_ORIGINS` com as origens separadas por vírgula. Apps nativos não passam por CORS.
- Documentação interativa (Swagger/OpenAPI) fica para quando a API crescer além de auth/vinculação.
