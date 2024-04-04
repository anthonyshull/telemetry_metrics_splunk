defmodule TelemetryMetricsSplunk.MixProject do
  use Mix.Project

  def project do
    [
      app: :telemetry_metrics_splunk,
      version: "0.0.1",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:inets, :logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "1.4.1"},
      {:plug_cowboy, "2.7.1", only: [:test]},
      {:telemetry, "1.2.1"},
      {:telemetry_metrics, "1.0.0"}
    ]
  end
end
