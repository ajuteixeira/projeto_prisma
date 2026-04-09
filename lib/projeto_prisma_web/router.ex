defmodule ProjetoPrismaWeb.Router do
  use ProjetoPrismaWeb, :router

  import ProjetoPrismaWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ProjetoPrismaWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ProjetoPrismaWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/", PageController, :connect_platforms
    get "/connect-platforms", PageController, :connect_platforms
  end

  scope "/", ProjetoPrismaWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/register", PageController, :register
    post "/complete-registration", PageController, :complete_registration
    post "/register", PageController, :create_profile
    get "/forgot-password", PageController, :forgot_password
    post "/forgot-password", PageController, :submit_forgot_password
    get "/reset-password", PageController, :reset_password
    post "/reset-password", PageController, :submit_reset_password
  end

  # Other scopes may use custom stacks.
  # scope "/api", ProjetoPrismaWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:projeto_prisma, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
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

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
  end

  scope "/", ProjetoPrismaWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
  end

  scope "/", ProjetoPrismaWeb do
    pipe_through [:browser]

    # Legacy auth paths kept for compatibility with old links/bookmarks.
    get "/log-in", UserSessionController, :new
    get "/log-in/:token", UserSessionController, :confirm
    post "/log-in", UserSessionController, :create
    delete "/log-out", UserSessionController, :delete

    get "/users/log-in", UserSessionController, :new
    get "/users/log-in/:token", UserSessionController, :confirm
    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
