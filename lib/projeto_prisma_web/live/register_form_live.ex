defmodule ProjetoPrismaWeb.RegisterFormLive do
  use ProjetoPrismaWeb, :live_view

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Services.EmailResend

  @max_attempts 5
  @code_expiry_minutes 10
  @resend_cooldown 60

  @impl true
  def mount(_params, _session, socket) do
    form =
      to_form(
        %{
          "full_name" => "",
          "nickname" => "",
          "email" => "",
          "password" => "",
          "confirm_password" => ""
        },
        as: :register
      )

    {:ok,
     socket
     |> assign(:form, form)
     |> assign(:form_errors, [])
     |> assign(:show_password, false)
     |> assign(:show_confirm_password, false)
     |> assign(:registration_complete, false)
     |> assign(:registration_token, nil)
     |> assign(:step, :form)
     |> assign(:verification_code, nil)
     |> assign(:form_params, nil)
     |> assign(:code_sent_at, nil)
     |> assign(:countdown, 0)
     |> assign(:code_attempts, 0)
     |> assign(:code_error, nil)}
  end

  @impl true
  def handle_event("toggle_password", %{"field" => field}, socket) do
    case field do
      "password" ->
        {:noreply, assign(socket, :show_password, !socket.assigns.show_password)}

      "confirm_password" ->
        {:noreply, assign(socket, :show_confirm_password, !socket.assigns.show_confirm_password)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("validate", %{"register" => params}, socket) do
    {:noreply,
     socket
     |> assign(:form, to_form(params, as: :register))
     |> assign(:form_errors, [])}
  end

  def handle_event("submit_register", %{"register" => params}, socket) do
    full_name = String.trim(params["full_name"] || "")

    nickname =
      params["nickname"]
      |> String.trim()
      |> String.downcase()
      |> String.replace(~r/\s+/, "_")

    email =
      params["email"]
      |> String.trim()
      |> String.downcase()

    password = params["password"] || ""
    confirm_password = params["confirm_password"] || ""

    cond do
      String.length(full_name) < 3 ->
        {:noreply,
         assign(socket, :form_errors, [{:full_name, "deve ter no minimo 3 caracteres"}])}

      String.length(nickname) < 3 ->
        {:noreply, assign(socket, :form_errors, [{:username, "deve ter no minimo 3 caracteres"}])}

      not Regex.match?(~r/^[a-z0-9_]+$/, nickname) ->
        {:noreply,
         assign(socket, :form_errors, [
           {:username, "deve conter apenas letras minusculas, numeros e underscore (_)"}
         ])}

      String.length(password) < 6 ->
        {:noreply, assign(socket, :form_errors, [{:password, "deve ter no minimo 6 caracteres"}])}

      password != confirm_password ->
        {:noreply,
         assign(socket, :form_errors, [{:confirm_password, "nao coincide com a senha"}])}

      true ->
        send_code_and_advance(socket, %{
          "username" => nickname,
          "email" => email,
          "password" => password,
          "full_name" => full_name
        })
    end
  end

  def handle_event("verify_code", %{"code" => input_code}, socket) do
    input_code = String.trim(input_code)
    %{verification_code: code, code_sent_at: sent_at, code_attempts: attempts} = socket.assigns

    cond do
      DateTime.diff(DateTime.utc_now(), sent_at, :minute) >= @code_expiry_minutes ->
        {:noreply,
         socket
         |> assign(:step, :form)
         |> assign(:form_errors, [{:email, "O código expirou. Tente novamente."}])}

      attempts >= @max_attempts ->
        {:noreply,
         socket
         |> assign(:step, :form)
         |> assign(:form_errors, [{:email, "Muitas tentativas incorretas. Tente novamente."}])}

      input_code != code ->
        new_attempts = attempts + 1

        error =
          if new_attempts >= @max_attempts,
            do: "Código incorreto. Número máximo de tentativas atingido.",
            else: "Código incorreto. #{@max_attempts - new_attempts} tentativa(s) restante(s)."

        {:noreply,
         socket
         |> assign(:code_attempts, new_attempts)
         |> assign(:code_error, error)}

      true ->
        register_user(socket, socket.assigns.form_params)
    end
  end

  def handle_event("back_to_form", _params, socket) do
    {:noreply,
     socket
     |> assign(:step, :form)
     |> assign(:code_error, nil)}
  end

  def handle_event("resend_code", _params, socket) do
    if socket.assigns.countdown > 0 do
      {:noreply, socket}
    else
      email = socket.assigns.form_params["email"]
      send_code_and_start_countdown(socket, email)
    end
  end

  @impl true
  def handle_info(:tick, socket) do
    if socket.assigns.countdown > 0 do
      Process.send_after(self(), :tick, 1000)
      {:noreply, assign(socket, :countdown, socket.assigns.countdown - 1)}
    else
      {:noreply, socket}
    end
  end

  defp send_code_and_advance(socket, params) do
    email = params["email"]

    if Accounts.get_user_by_email(email) do
      {:noreply, assign(socket, :form_errors, [{:email, "Este e-mail já está em uso, escolha outro."}])}
    else
      case send_code_and_start_countdown(socket, email) do
        {:noreply, updated_socket} ->
          {:noreply,
           updated_socket
           |> assign(:step, :verification)
           |> assign(:form_params, params)
           |> assign(:code_attempts, 0)
           |> assign(:code_error, nil)}
      end
    end
  end

  defp send_code_and_start_countdown(socket, email) do
    code = generate_code()
    EmailResend.send_verification_code_email(email, code)
    Process.send_after(self(), :tick, 1000)

    {:noreply,
     socket
     |> assign(:verification_code, code)
     |> assign(:code_sent_at, DateTime.utc_now())
     |> assign(:countdown, @resend_cooldown)}
  end

  defp register_user(socket, attrs) do
    with {:ok, user} <- Accounts.register_user_legacy(attrs),
         {:ok, profile} <- Accounts.create_profile_for_user(user) do
      token =
        Phoenix.Token.sign(
          ProjetoPrismaWeb.Endpoint,
          "registration",
          %{user_id: user.id, profile_id: profile.id}
        )

      {:noreply,
       socket
       |> assign(:registration_token, token)
       |> assign(:registration_complete, true)}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        errors =
          changeset
          |> Ecto.Changeset.traverse_errors(fn {msg, opts} -> translate_error({msg, opts}) end)
          |> Enum.flat_map(fn {field, messages} ->
            Enum.map(messages, fn message -> {field, format_error_message(field, message)} end)
          end)

        {:noreply,
         socket
         |> assign(:step, :form)
         |> assign(:form_errors, errors)}
    end
  end

  defp generate_code do
    :rand.uniform(999_999)
    |> Integer.to_string()
    |> String.pad_leading(6, "0")
  end

  defp field_label(:full_name), do: "Nome completo"
  defp field_label(:username), do: "Nickname"
  defp field_label(:email), do: "E-mail"
  defp field_label(:password), do: "Senha"
  defp field_label(:confirm_password), do: "Confirmar senha"

  defp field_label(field),
    do: field |> to_string() |> String.replace("_", " ") |> String.capitalize()

  defp format_error_message(:username, "has already been taken") do
    "O nome de usuario escolhido já está em uso, por favor altere."
  end

  defp format_error_message(:email, "has already been taken") do
    "Este e-mail já está em uso, escolha outro."
  end

  defp format_error_message(_field, message), do: message

  @impl true
  def render(assigns) do
    ~H"""
    <%= if @registration_complete do %>
      <form
        id="complete-registration-form"
        action="/complete-registration"
        method="post"
        phx-hook="AutoSubmit"
      >
        <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
        <input type="hidden" name="token" value={@registration_token} />
        <p style="text-align: center; color: #a0a0a0;">Finalizando cadastro...</p>
      </form>
    <% else %>
      <%= if @step == :verification do %>
        <div style="text-align: center;">
          <i class="fas fa-envelope-open-text" style="font-size: 48px; color: #007bff; margin-bottom: 16px;"></i>
          <h3 style="margin-bottom: 8px;">Verifique seu email</h3>
          <p style="color: #a0a0a0; margin-bottom: 24px;">
            Enviamos um código de 6 dígitos para <strong>{@form_params["email"]}</strong>
          </p>
        </div>

        <div :if={@code_error} class="error-message" style="display: flex;">
          <i class="fas fa-exclamation-circle"></i>
          <div class="error-message-content">
            <p>{@code_error}</p>
          </div>
        </div>

        <form phx-submit="verify_code">
          <div class="form-group">
            <label class="form-label">Código de verificação</label>
            <div class="input-wrapper">
              <i class="fas fa-key input-icon"></i>
              <input
                type="text"
                name="code"
                class="form-input"
                placeholder="000000"
                maxlength="6"
                autocomplete="one-time-code"
                autofocus
                style="letter-spacing: 8px; font-size: 20px; text-align: center;"
              />
            </div>
          </div>

          <button type="submit" class="register-btn">
            Confirmar código
          </button>
        </form>

        <div style="text-align: center; margin-top: 16px;">
          <button
            phx-click="resend_code"
            disabled={@countdown > 0}
            style={"background: none; border: none; cursor: #{if @countdown > 0, do: "not-allowed", else: "pointer"}; color: #{if @countdown > 0, do: "#a0a0a0", else: "#007bff"}; font-size: 14px;"}
          >
            <%= if @countdown > 0 do %>
              Reenviar código em {@countdown}s
            <% else %>
              Reenviar código
            <% end %>
          </button>
        </div>

        <div style="text-align: center; margin-top: 12px;">
          <button
            phx-click="back_to_form"
            style="background: none; border: none; cursor: pointer; color: #a0a0a0; font-size: 13px;"
          >
            ← Voltar e alterar dados
          </button>
        </div>
      <% else %>
        <div :if={@form_errors != []} class="error-message" id="errorMessage" style="display: flex;">
          <i class="fas fa-exclamation-circle"></i>
          <div class="error-message-content" id="errorText">
            <p class="error-message-title">Verifique os campos abaixo:</p>
            <ul class="error-message-list">
              <li :for={{field, message} <- @form_errors}>
                {field_label(field)}: {message}
              </li>
            </ul>
          </div>
        </div>

        <.form
          for={@form}
          id="registerForm"
          phx-submit="submit_register"
          phx-change="validate"
        >
          <div class="form-group">
            <label class="form-label">Nome Completo</label>
            <div class="input-wrapper">
              <i class="fas fa-user input-icon"></i>
              <input
                type="text"
                name="register[full_name]"
                id="fullName"
                class="form-input"
                placeholder="Seu nome completo"
                value={@form[:full_name].value}
                required
                minlength="3"
              />
            </div>
          </div>

          <div class="form-group">
            <label class="form-label">Nickname</label>
            <div class="input-wrapper">
              <i class="fas fa-at input-icon"></i>
              <input
                type="text"
                name="register[nickname]"
                id="nickname"
                class="form-input"
                placeholder="seu_nickname"
                value={@form[:nickname].value}
                required
                minlength="3"
                style="text-transform: lowercase;"
              />
            </div>
            <p class="nickname-hint">
              Apenas letras minusculas, numeros e underscore. Este sera seu @nome de usuario
            </p>
          </div>

          <div class="form-group">
            <label class="form-label">E-mail</label>
            <div class="input-wrapper">
              <i class="fas fa-envelope input-icon"></i>
              <input
                type="email"
                name="register[email]"
                id="email"
                class="form-input"
                placeholder="seu@email.com"
                value={@form[:email].value}
                required
              />
            </div>
          </div>

          <div class="form-group">
            <label class="form-label">Senha</label>
            <div class="input-wrapper">
              <i class="fas fa-lock input-icon"></i>
              <input
                type={if @show_password, do: "text", else: "password"}
                name="register[password]"
                id="password"
                class="form-input"
                placeholder="digite sua senha"
                value={@form[:password].value}
                required
                minlength="6"
              />
              <button
                type="button"
                class="password-toggle"
                phx-click="toggle_password"
                phx-value-field="password"
              >
                <i
                  class={"fas #{if @show_password, do: "fa-eye-slash", else: "fa-eye"}"}
                  id="toggleIcon1"
                >
                </i>
              </button>
            </div>
          </div>

          <div class="form-group">
            <label class="form-label">Confirmar Senha</label>
            <div class="input-wrapper">
              <i class="fas fa-lock input-icon"></i>
              <input
                type={if @show_confirm_password, do: "text", else: "password"}
                name="register[confirm_password]"
                id="confirmPassword"
                class="form-input"
                placeholder="confirme sua senha"
                value={@form[:confirm_password].value}
                required
                minlength="6"
              />
              <button
                type="button"
                class="password-toggle"
                phx-click="toggle_password"
                phx-value-field="confirm_password"
              >
                <i
                  class={"fas #{if @show_confirm_password, do: "fa-eye-slash", else: "fa-eye"}"}
                  id="toggleIcon2"
                >
                </i>
              </button>
            </div>
          </div>

          <button type="submit" class="register-btn" phx-disable-with="Enviando código...">
            Criar Conta
          </button>
        </.form>

        <div class="login-link">
          Ja tem uma conta? <a href="/users/log-in">Voltar para o Login</a>
        </div>
      <% end %>
    <% end %>
    """
  end
end
