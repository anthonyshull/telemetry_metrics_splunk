defmodule TelemetryMetricsSplunkTest do
  use ExUnit.Case, async: true

  alias Telemetry.Metrics

  @port 9999
  @options [
    url: "http://localhost:#{@port}/services/collector",
    token: "00000000-0000-0000-0000-000000000000"
  ]

  setup do
    children = [
      {
        Plug.Cowboy,
        [
          scheme: :http,
          plug: TelemetryMetricsSplunk.Hec.Mock,
          options: [port: @port]
        ]
      }
    ]
    options = [strategy: :one_for_one, name: __MODULE__]

    Supervisor.start_link(children, options)

    :ok
  end

  test "greets the world" do
    @options
    |> Keyword.put(:metrics, [Metrics.last_value("foo.bar.baz"), Metrics.last_value("foo.bar.bop")])
    |> TelemetryMetricsSplunk.start_link()

    :telemetry.execute([:foo, :bar], %{baz: :rand.uniform(999), bop: :rand.uniform(999)})
  end
end
