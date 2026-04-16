defmodule ProjetoPrismaWeb.Layouts.Navbar do
  use ProjetoPrismaWeb, :html

  @doc """
  Renderiza a sidebar de navegação lateral do Prisma.

  No desktop: sidebar vertical fixada à esquerda (56px de largura).
  No mobile: barra de navegação horizontal fixada na parte inferior.

  ## Atributos
    - `current_scope` - escopo atual do usuário autenticado (pode ser nil)
    - `current_path` - path atual da requisição para destacar o item ativo (opcional)
  """
  attr :current_scope, :map, default: nil
  attr :current_path, :string, default: "/"

  def render_navbar(assigns) do
    ~H"""
    <nav class="sidebar" aria-label="Navegação principal">
      <%!-- Ícone: Dashboard --%>
      <.sidebar_icon
        href={~p"/"}
        label="Dashboard"
        active={@current_path == "/"}
        icon="fa-gamepad"
      />

      <%!-- Ícone: Ranking --%>
      <.sidebar_icon
        href={~p"/ranking"}
        label="Ranking"
        active={String.starts_with?(@current_path, "/ranking")}
        icon="fa-trophy"
      />

      <%!-- Ícone: Seguidores --%>
      <.sidebar_icon
        href={~p"/followers"}
        label="Seguidores"
        active={String.starts_with?(@current_path, "/followers")}
        icon="fa-users"
      />

      <%!-- Espaço flexível — empurra as configurações para o fim (só no desktop) --%>
      <div class="flex-1 hidden md:block" aria-hidden="true"></div>

      <%!-- Ícone: Configurações (usuário logado) ou Login (visitante) --%>
      <%= if @current_scope do %>
        <.sidebar_icon
          href={~p"/users/settings"}
          label="Configurações"
          active={String.starts_with?(@current_path, "/users/settings")}
          icon="fa-cog"
        />
      <% else %>
        <.sidebar_icon
          href={~p"/users/log-in"}
          label="Entrar"
          active={String.starts_with?(@current_path, "/users/log-in")}
          icon="fa-right-to-bracket"
        />
      <% end %>
    </nav>
    """
  end

  # Componente interno: um ícone da sidebar com tooltip, estado ativo e link
  attr :href, :string, required: true
  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :active, :boolean, default: false

  defp sidebar_icon(assigns) do
    ~H"""
    <.link
      href={@href}
      class={["sidebar-icon", @active && "active"]}
      title={@label}
      aria-label={@label}
      aria-current={@active && "page"}
    >
      <i class={"fas #{@icon}"} aria-hidden="true"></i>
    </.link>
    """
  end
end
