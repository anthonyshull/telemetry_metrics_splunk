defmodule TelemetryMetricsSplunkTest do
  use ExUnit.Case, async: false

  alias Telemetry.Metrics

  @port 9999
  @options [
    finch: Test.Finch,
    metrics: [],
    token: "00000000-0000-0000-0000-000000000000",
    url: "http://localhost:#{@port}/services/collector"
  ]

  setup do
    bypass = Bypass.open(port: @port)
    finch = Finch.start_link(name: @options[:finch])

    {:ok, bypass: bypass, finch: finch}
  end

  test "allows two instances to be started" do
    assert {:ok, _} = Supervisor.start_link([{TelemetryMetricsSplunk, @options}], strategy: :one_for_one)
    assert {:ok, _} = Supervisor.start_link([{TelemetryMetricsSplunk, @options}], strategy: :one_for_one)
  end

  describe "options" do
    test "allows :finch, :token, and :url to be nil" do
      Enum.each([:finch, :token, :url], fn key ->
        options = Keyword.delete(@options, key)

        assert {:ok, pid} =
                 Supervisor.start_link([{TelemetryMetricsSplunk, options}], strategy: :one_for_one)

        Supervisor.stop(pid)
      end)
    end

    test "does not allow :metrics to be nil" do
      options = Keyword.delete(@options, :metrics)

      Process.flag(:trap_exit, true)

      pid =
        spawn_link(fn ->
          Supervisor.start_link([{TelemetryMetricsSplunk, options}], strategy: :one_for_one)
        end)

      assert_receive {:EXIT, ^pid, _}
    end
  end

  test "sends the metric to splunk", %{bypass: bypass} do
    metric = :rand.uniform(999)

    options = Keyword.put(@options, :metrics, [Metrics.last_value("foo.bar.baz")])

    Supervisor.start_link([{TelemetryMetricsSplunk, options}], strategy: :one_for_one)

    Bypass.expect_once(bypass, "POST", "/services/collector", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn, read_timeout: 500)
      data = Jason.decode!(body)

      assert data["fields"]["metric_name:foo.bar.baz.last_value"] == metric

      Plug.Conn.resp(conn, 200, "ok")
    end)

    :telemetry.execute([:foo, :bar], %{baz: metric})
  end
end
