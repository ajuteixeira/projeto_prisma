#!/usr/bin/env python3
"""
Gera o diagrama de arquitetura do sistema Prisma.
Execute com:
    nix-shell -p graphviz --run "/home/bruno/.local/share/pipx/venvs/diagrams/bin/python arquitetura_prisma.py"
"""

from diagrams import Diagram, Cluster, Edge
from diagrams.programming.framework import Phoenix
from diagrams.onprem.database import PostgreSQL
from diagrams.onprem.client import User
from diagrams.generic.network import Firewall
from diagrams.generic.compute import Rack
from diagrams.generic.storage import Storage

graph_attr = {
    "bgcolor": "#f8f9fa",
    "pad": "0.4",
    "nodesep": "0.5",
    "ranksep": "0.8",
    "fontname": "Helvetica",
    "fontsize": "13",
    "fontcolor": "#212529",
}

node_attr = {
    "fontname": "Helvetica",
    "fontsize": "11",
    "fontcolor": "#212529",
}

edge_attr = {
    "color": "#495057",
    "fontcolor": "#495057",
    "fontname": "Helvetica",
    "fontsize": "9",
}

with Diagram(
    "Arquitetura do Sistema Prisma",
    show=False,
    filename="docs/arquitetura_prisma",
    direction="TB",
    graph_attr=graph_attr,
    node_attr=node_attr,
    edge_attr=edge_attr,
    outformat="png",
):
    usuario = User("Usuário\n(Navegador)")

    # ============================================================
    # CAMADA DE APRESENTAÇÃO
    # ============================================================
    with Cluster("CAMADA DE APRESENTAÇÃO", graph_attr={"bgcolor": "#e3f2fd", "style": "rounded", "color": "#1976d2", "fontcolor": "#0d47a1"}):
        liveview = Phoenix("Phoenix LiveView")
        tailwind = Rack("Tailwind CSS\n+ Heroicons")
        websocket = Firewall("WebSocket\n(Realtime)")

    # ============================================================
    # CAMADA DE APLICAÇÃO
    # ============================================================
    with Cluster("CAMADA DE APLICAÇÃO", graph_attr={"bgcolor": "#f3e5f5", "style": "rounded", "color": "#7b1fa2", "fontcolor": "#4a148c"}):
        phoenix = Phoenix("Phoenix v1.8\n(Elixir / OTP)")

        with Cluster("Contextos de Negócio", graph_attr={"bgcolor": "#ede7f6", "style": "dashed", "color": "#9c27b0", "fontcolor": "#6a1b9a"}):
            accounts = Rack("Accounts\n(Usuários, Perfis,\nSeguidores)")
            catalog = Rack("Catalog\n(Jogos, Conquistas,\nPlataformas)")
            sync = Rack("Sync\n(Sincronização)")

        with Cluster("Integrações Externas", graph_attr={"bgcolor": "#ede7f6", "style": "dashed", "color": "#9c27b0", "fontcolor": "#6a1b9a"}):
            steam = Storage("Steam API")
            psn = Storage("PlayStation\nAPI")
            xbox = Storage("Xbox API")
            retro = Storage("RetroAchievements\nAPI")
            igdb = Storage("IGDB API")

    # ============================================================
    # CAMADA DE DADOS
    # ============================================================
    with Cluster("CAMADA DE DADOS", graph_attr={"bgcolor": "#e8f5e9", "style": "rounded", "color": "#388e3c", "fontcolor": "#1b5e20"}):
        ecto = Rack("Ecto\n(ORM / Changesets)")
        postgres = PostgreSQL("PostgreSQL")

    # ============================================================
    # INFRAESTRUTURA
    # ============================================================
    with Cluster("INFRAESTRUTURA", graph_attr={"bgcolor": "#fff3e0", "style": "rounded", "color": "#f57c00", "fontcolor": "#e65100"}):
        bandit = Firewall("Bandit\n(Servidor HTTP)")
        telemetry = Rack("Telemetry\n(Métricas)")
        rate = Firewall("Rate Limiter")
        mailer = Storage("Swoosh / Resend\n(E-mails)")

    # ============================================================
    # FLUXOS DE COMUNICAÇÃO
    # ============================================================

    # Usuário entra no sistema
    usuario >> Edge(label="HTTPS") >> bandit
    bandit >> liveview

    # LiveView se comunica com backend via WebSocket
    liveview >> websocket >> phoenix
    liveview >> tailwind

    # Backend acessa contextos de negócio
    phoenix >> accounts
    phoenix >> catalog
    phoenix >> sync

    # Sync acessa APIs externas com rate limiting
    sync >> rate
    rate >> steam
    rate >> psn
    rate >> xbox
    rate >> retro
    rate >> igdb

    # Contextos persistem no banco via Ecto
    accounts >> ecto
    catalog >> ecto
    sync >> ecto
    ecto >> postgres

    # Infraestrutura auxiliar
    phoenix >> telemetry
    phoenix >> mailer
