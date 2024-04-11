defmodule TelemetryMetricsSplunkTest do
  use ExUnit.Case, async: false

  alias Telemetry.Metrics

  @port 9999
  @options [
    token: "00000000-0000-0000-0000-000000000000",
    url: "http://localhost:#{@port}/services/collector"
  ]

  setup do
    bypass = Bypass.open(port: @port)

    {:ok, bypass: bypass}
  end

  test "sends the metric to splunk", %{bypass: bypass} do
    metric = :rand.uniform(999)

    options = Keyword.put(@options, :metrics, [Metrics.last_value("foo.bar.baz")])

    Supervisor.start_link([{TelemetryMetricsSplunk, options}], strategy: :one_for_one, name: __MODULE__)

    Bypass.expect_once(bypass, "POST", "/services/collector", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn, read_timeout: 500)
      data = Jason.decode!(body)

      assert data["fields"]["metric_name:foo.bar.baz.last_value"] == metric

      Plug.Conn.resp(conn, 200, "ok")
    end)

    :telemetry.execute([:foo, :bar], %{baz: metric})
  end
end
