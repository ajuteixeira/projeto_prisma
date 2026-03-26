defmodule ProjetoPrismaWeb.PageController do
  use ProjetoPrismaWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def connect_platforms(conn, _params) do
    render(conn, :connect_platforms)
  end
end
