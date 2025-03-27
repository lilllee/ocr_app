defmodule OcrApp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      OcrAppWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: OcrApp.PubSub},
      # Start the Endpoint (http/https)
      OcrAppWeb.Endpoint
      # Start a worker by calling: OcrApp.Worker.start_link(arg)
      # {OcrApp.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: OcrApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    OcrAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
