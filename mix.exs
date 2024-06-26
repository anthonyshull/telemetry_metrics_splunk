defmodule TelemetryMetricsSplunk.MixProject do
  use Mix.Project

  @version "0.0.6-alpha"

  def project do
    [
      app: :telemetry_metrics_splunk,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "TelemetryMetricsSplunk",
      description: "Telemetry.Metrics reporter for Splunk metrics indexes using the Splunk HTTP Event Collector (HEC)",
      docs: [
        main: "TelemetryMetricsSplunk",
        canonical: "http://hexdocs.pm/telemetry_metrics_splunk",
        source_url: "https://github.com/anthonyshull/telemetry_metrics_splunk",
        source_ref: "v#{@version}"
      ],
      package: [
        licenses: ["GPL-3.0-or-later"],
        links: %{"GitHub" => "https://github.com/anthonyshull/telemetry_metrics_splunk"}
      ],
      test_coverage: [tool: ExCoveralls]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:inets, :logger, :ssl]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bypass, "2.1.0", only: [:test]},
      {:credo, "1.7.5", only: [:dev], runtime: false},
      {:ex_doc, "0.32.0", only: [:dev], runtime: false},
      {:excoveralls, "0.18.1", only: [:test]},
      {:finch, "~> 0.18"},
      {:dialyxir, "1.4.3", only: [:dev], runtime: false},
      {:jason, "~> 1.4"},
      {:nimble_options, "~> 1.1"},
      {:recase, "~> 0.8"},
      {:telemetry, "~> 1.2"},
      {:telemetry_metrics, "~> 1.0"}
    ]
  end
end
