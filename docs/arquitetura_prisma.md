# Arquitetura do Sistema Prisma

O sistema **Prisma** foi projetado utilizando uma **Arquitetura em Camadas (Monolito Modular)** — ou seja, todo o código roda em uma única aplicação, mas está organizado em módulos independentes (Contexts, Adapters, LiveViews) que podem ser evoluídos separadamente sem bagunçar o restante do sistema.

---

## Camada de Apresentação (Frontend)

Desenvolvida com **Phoenix LiveView** e estilizada com **Tailwind CSS** e **Heroicons**. Esta camada é responsável por fornecer uma interface de usuário rica, reativa e em tempo real. A escolha do LiveView justifica-se pela sua capacidade de renderizar atualizações dinâmicas no lado do servidor e enviá-las via **WebSockets**, eliminando a necessidade de uma API REST separada e simplificando a sincronização de estado entre cliente e servidor.

---

## Camada de Aplicação (Backend)

Desenvolvida em **Elixir** com o framework **Phoenix v1.8**. Esta camada gerencia a lógica de negócio através de **Contextos** (`Accounts`, `Catalog`, `Sync`), que agrupam funcionalidades relacionadas de forma isolada.

Para se comunicar com as plataformas de jogos (**Steam**, **PlayStation**, **Xbox**, **RetroAchievements**, **IGDB**), o sistema usa o padrão **Adapter** — cada plataforma tem um "tradutor" próprio que converte os dados da API externa para o formato interno do Prisma. Um **Rate Limiter** controla o volume de requisições para evitar bloqueios por excesso de chamadas.

O **Elixir** foi escolhido por sua alta concorrência e tolerância a falhas nativa (graças à máquina virtual **Erlang/OTP**), garantindo o processamento de milhares de eventos simultâneos com baixa latência.

---

## Camada de Dados (Banco de Dados)

O sistema utiliza o banco de dados **PostgreSQL**, selecionado por sua robustez e conformidade com as propriedades **ACID**. A biblioteca **Ecto** gerencia a persistência, garantindo a integridade dos dados via **schemas** e **changesets**, que permitem validações rigorosas antes de qualquer gravação.

---

## Infraestrutura de Suporte

O servidor HTTP é o **Bandit**, que substitui o Cowboy como adapter do Phoenix. O sistema conta com:

- **Telemetry** — coleta de métricas em tempo real
- **Swoosh** com adapter **Resend** — envio de e-mails transacionais (confirmação de cadastro, recuperação de senha)
- **DNSCluster** — descoberta de nós em ambiente distribuído
