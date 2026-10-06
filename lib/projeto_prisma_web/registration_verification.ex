defmodule ProjetoPrismaWeb.RegistrationVerification do
  @moduledoc """
  Código de confirmação de e-mail do cadastro via API.

  O código não é persistido: vai criptografado num token junto do e-mail e é
  conferido quando o token volta. Criptografado, e não só assinado, para que
  quem recebe o token não consiga ler o código.
  """

  alias ProjetoPrismaWeb.Endpoint

  @salt "registration-verification"
  # Mesmos prazos do cadastro web (`RegisterFormLive`).
  @max_age_in_seconds 600
  @resend_after_in_seconds 60

  @doc "Código numérico de 6 dígitos, com zeros à esquerda."
  def generate_code do
    :crypto.strong_rand_bytes(4)
    |> :binary.decode_unsigned()
    |> rem(1_000_000)
    |> Integer.to_string()
    |> String.pad_leading(6, "0")
  end

  @doc """
  Criptografa `code` junto de `email` num token.

  `email` deve estar normalizado (sem espaços, em minúsculas), pois `check/3`
  compara o valor exato. `opts` é repassado a `Phoenix.Token.encrypt/4`.
  """
  def encrypt(email, code, opts \\ []) when is_binary(email) and is_binary(code) do
    Phoenix.Token.encrypt(Endpoint, @salt, %{email: email, code: code}, opts)
  end

  @doc """
  Confere o código digitado contra o token emitido para `email`.

  Retorna `:ok`, `{:error, :expired}` (token com mais de `max_age/0` segundos),
  `{:error, :invalid_token}` (adulterado ou emitido para outro e-mail) ou
  `{:error, :invalid_code}`.
  """
  def check(token, email, code)
      when is_binary(token) and is_binary(email) and is_binary(code) do
    case Phoenix.Token.decrypt(Endpoint, @salt, token, max_age: @max_age_in_seconds) do
      {:ok, %{email: ^email, code: expected}} ->
        if Plug.Crypto.secure_compare(expected, code), do: :ok, else: {:error, :invalid_code}

      {:ok, _other_email} ->
        {:error, :invalid_token}

      {:error, :expired} ->
        {:error, :expired}

      {:error, _reason} ->
        {:error, :invalid_token}
    end
  end

  def check(_token, _email, _code), do: {:error, :invalid_token}

  @doc "Validade do token, em segundos."
  def max_age, do: @max_age_in_seconds

  @doc "Espera sugerida antes de pedir outro código, em segundos. Não é imposta aqui."
  def resend_after, do: @resend_after_in_seconds
end
