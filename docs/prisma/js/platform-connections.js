class PlatformConnectionsManager {
  constructor() {
    this.platforms = ["steam", "playstation", "xbox", "retro"];
    this.sessionId = null;
    this.connections = {
      steam: false,
      playstation: false,
      xbox: false,
      retro: false,
    };
  }

  getSessionId() {
    let sessionId = localStorage.getItem("prisma_session_id");

    if (!sessionId) {
      sessionId =
        "session_" + Date.now() + "_" + Math.random().toString(36).substr(2, 9);
      localStorage.setItem("prisma_session_id", sessionId);
    }

    return sessionId;
  }

  async init() {
    try {
      this.sessionId = this.getSessionId();
      console.log("Session ID:", this.sessionId);
      await this.loadConnectionsFromSupabase();
      return true;
    } catch (error) {
      console.error("Error initializing connections manager:", error);
      this.loadFromLocalStorage();
      return false;
    }
  }

  async loadConnectionsFromSupabase() {
    try {
      const { data, error } = await supabaseClient
        .from("user_connections")
        .select("*")
        .eq("session_id", this.sessionId)
        .single();

      if (error) {
        if (error.code === "PGRST116") {
          console.log("Criando novo registro de conexões...");
          await this.createConnectionsRecord();
        } else {
          throw error;
        }
      } else {
        this.connections = {
          steam: data.steam_connected || false,
          playstation: data.psn_connected || false,
          xbox: data.xbox_connected || false,
          retro: data.retroarch_connected || false,
        };
        console.log("Conexões carregadas do Supabase:", this.connections);
      }
      this.updateUI();
    } catch (error) {
      console.error("Error loading connections from Supabase:", error);
      throw error;
    }
  }

  async createConnectionsRecord() {
    try {
      const { data, error } = await supabaseClient
        .from("user_connections")
        .insert([
          {
            session_id: this.sessionId,
            steam_connected: false,
            psn_connected: false,
            xbox_connected: false,
            retroarch_connected: false,
          },
        ])
        .select()
        .single();

      if (error) throw error;

      console.log("Registro criado com sucesso:", data);
    } catch (error) {
      console.error("Error creating connections record:", error);
      throw error;
    }
  }

  async connectPlatform(platform) {
    try {
      console.log(`🔗 Conectando ${platform}...`);
      if (!this.platforms.includes(platform)) {
        throw new Error(`Invalid platform: ${platform}`);
      }
      if (this.connections[platform]) {
        console.log(`Platform ${platform} já está conectada`);
        return true;
      }
      if (typeof supabaseClient === "undefined" || !supabaseClient) {
        console.warn(
          "⚠️ Supabase client não disponível, usando apenas localStorage"
        );
        this.connections[platform] = true;
        this.saveToLocalStorage();
        this.markAsConnected(platform);
        return true;
      }
      if (!this.sessionId) {
        console.error("❌ Session ID não definido");
        throw new Error("Session ID não encontrado");
      }
      const columnName = this.getPlatformColumnName(platform);
      console.log(
        `📤 Atualizando ${columnName} = true para session_id:`,
        this.sessionId
      );

      const { data, error } = await supabaseClient
        .from("user_connections")
        .update({ [columnName]: true })
        .eq("session_id", this.sessionId)
        .select()
        .single();

      if (error) {
        console.error("❌ Erro do Supabase:", error);
        throw error;
      }

      console.log(`✓ ${platform} conectada:`, data);
      this.connections[platform] = true;
      this.saveToLocalStorage();
      this.markAsConnected(platform);

      return true;
    } catch (error) {
      console.error(`❌ Error connecting platform ${platform}:`, error);
      console.error("Detalhes do erro:", {
        message: error.message,
        code: error.code,
        details: error.details,
        hint: error.hint,
      });
      throw error;
    }
  }

  async disconnectPlatform(platform) {
    try {
      console.log(`🔌 Desvinculando ${platform}...`);
      if (!this.platforms.includes(platform)) {
        throw new Error(`Invalid platform: ${platform}`);
      }
      if (!this.connections[platform]) {
        console.log(`Platform ${platform} já está desconectada`);
        return true;
      }
      if (typeof supabaseClient === "undefined" || !supabaseClient) {
        console.warn(
          "⚠️ Supabase client não disponível, usando apenas localStorage"
        );
        this.connections[platform] = false;
        this.saveToLocalStorage();
        this.markAsDisconnected(platform);
        return true;
      }
      if (!this.sessionId) {
        console.error("❌ Session ID não definido");
        throw new Error("Session ID não encontrado");
      }

      const columnName = this.getPlatformColumnName(platform);
      console.log(
        `📤 Atualizando ${columnName} = false para session_id:`,
        this.sessionId
      );

      const { data, error } = await supabaseClient
        .from("user_connections")
        .update({ [columnName]: false })
        .eq("session_id", this.sessionId)
        .select()
        .single();

      if (error) {
        console.error("❌ Erro do Supabase:", error);
        throw error;
      }

      console.log(`✓ ${platform} desconectada:`, data);
      this.connections[platform] = false;
      this.saveToLocalStorage();
      this.markAsDisconnected(platform);

      return true;
    } catch (error) {
      console.error(`❌ Error disconnecting platform ${platform}:`, error);
      console.error("Detalhes do erro:", {
        message: error.message,
        code: error.code,
        details: error.details,
        hint: error.hint,
      });
      throw error;
    }
  }

  async togglePlatform(platform) {
    if (this.connections[platform]) {
      return await this.disconnectPlatform(platform);
    } else {
      return await this.connectPlatform(platform);
    }
  }

  getPlatformColumnName(platform) {
    const columnMap = {
      steam: "steam_connected",
      playstation: "psn_connected",
      xbox: "xbox_connected",
      retro: "retroarch_connected",
    };
    return columnMap[platform];
  }

  areAllConnected() {
    return Object.values(this.connections).every((connected) => connected);
  }

  getConnectedCount() {
    return Object.values(this.connections).filter((connected) => connected)
      .length;
  }

  markAsConnected(platform) {
    const button = document.querySelector(`[data-platform="${platform}"]`);
    if (button) {
      button.classList.add("connected");
      button.innerHTML = '<i class="fas fa-check"></i> Vinculado';
      button.title = "Clique para desvincular";
    }
  }

  markAsDisconnected(platform) {
    const button = document.querySelector(`[data-platform="${platform}"]`);
    if (button) {
      button.classList.remove("connected");
      button.innerHTML = '<i class="fas fa-link"></i> Conectar';
      button.title = "Clique para conectar";
    }
  }

  updateUI() {
    this.platforms.forEach((platform) => {
      if (this.connections[platform]) {
        this.markAsConnected(platform);
      } else {
        this.markAsDisconnected(platform);
      }
    });
  }

  async handlePlatformConnect(platform, url) {
    try {
      window.open(url, "_blank", "noopener,noreferrer");
      await this.connectPlatform(platform);
      if (this.areAllConnected()) {
        setTimeout(() => {
          window.location.href = "dashboard.html";
        }, 1000);
      }
    } catch (error) {
      console.error("Error handling platform connect:", error);
      alert("Erro ao conectar plataforma. Por favor, tente novamente.");
    }
  }

  saveToLocalStorage() {
    const connectedPlatforms = this.platforms.filter(
      (p) => this.connections[p]
    );
    localStorage.setItem(
      "connectedPlatforms",
      JSON.stringify(connectedPlatforms)
    );
  }

  loadFromLocalStorage() {
    try {
      const saved = localStorage.getItem("connectedPlatforms");
      if (saved) {
        const connectedPlatforms = JSON.parse(saved);
        connectedPlatforms.forEach((platform) => {
          this.connections[platform] = true;
        });
        this.updateUI();
        console.log("Conexões carregadas do localStorage:", this.connections);
      }
    } catch (error) {
      console.error("Error loading from localStorage:", error);
    }
  }
}

window.PlatformConnectionsManager = PlatformConnectionsManager;
