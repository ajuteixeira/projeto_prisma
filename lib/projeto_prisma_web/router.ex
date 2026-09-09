defmodule ProjetoPrismaWeb.Router do
  use ProjetoPrismaWeb, :router

  import ProjetoPrismaWeb.UserAuth
  import ProjetoPrismaWeb.Plugs.ApiAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ProjetoPrismaWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    plug :assign_current_path
  end

  # Injeta o path atual nos assigns para que a sidebar possa destacar o item ativo
  defp assign_current_path(conn, _opts) do
    Plug.Conn.assign(conn, :current_path, conn.request_path)
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug :accepts, ["json"]
    plug :fetch_api_user
    plug :require_api_user
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:projeto_prisma, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ProjetoPrismaWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", ProjetoPrismaWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    post "/complete-registration", PageController, :complete_registration
    get "/reset-password", UserResetPasswordController, :new
    post "/reset-password", UserResetPasswordController, :create
    get "/reset-password/:token", UserResetPasswordController, :edit
    put "/reset-password/:token", UserResetPasswordController, :update

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
    get "/users/log-in", UserSessionController, :new
    get "/users/log-in/:token", UserSessionController, :confirm
    post "/users/log-in", UserSessionController, :create
  end

  scope "/", ProjetoPrismaWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/", PageController, :profile
    get "/followers", PageController, :followers
    get "/ranking", PageController, :ranking
    get "/auth/xbox/start", XboxOAuthController, :start
    post "/auth/steam/start", SteamOAuthController, :start
    get "/connect-platforms", PageController, :connect_platforms
    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    delete "/users/settings", UserSettingsController, :delete
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
    get "/users/log-out", UserSessionController, :delete
    delete "/users/log-out", UserSessionController, :delete
  end

  # Callbacks OAuth ficam fora do escopo autenticado: chegam por redirect externo
  # e a identificação do perfil vem da sessão (web) ou do state assinado (API mobile).
  scope "/", ProjetoPrismaWeb do
    pipe_through [:browser]

    get "/auth/xbox/callback", XboxOAuthController, :callback
    get "/auth/steam/callback", SteamOAuthController, :callback
  end

  ## API JSON (app mobile)

  scope "/api", ProjetoPrismaWeb.Api, as: :api do
    pipe_through :api

    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
    post "/auth/password/forgot", AuthController, :forgot_password
    post "/auth/password/reset", AuthController, :reset_password
  end

  scope "/api", ProjetoPrismaWeb.Api, as: :api do
    pipe_through :api_auth

    get "/auth/me", AuthController, :me
    post "/auth/logout", AuthController, :logout

    get "/platforms", PlatformController, :index
    post "/platforms/:slug/connect-url", PlatformController, :connect_url
    delete "/platforms/:slug", PlatformController, :delete
  end

  scope "/", ProjetoPrismaWeb do
    pipe_through [:browser]

    get "/:username", PageController, :friend_profile
  end
end
