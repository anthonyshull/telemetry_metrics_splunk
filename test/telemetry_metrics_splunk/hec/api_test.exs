defmodule TelemetryMetricsSplunk.Hec.ApiTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Telemetry.Metrics
  alias TelemetryMetricsSplunk.Hec.Api

  @port 9999
  @route "/services/collector"
  @options [
    url: "http://localhost:#{@port}#{@route}",
    token: "00000000-0000-0000-0000-000000000000"
  ]

  setup do
    bypass = Bypass.open(port: @port)

    {:ok, bypass: bypass}
  end

  describe "send/2" do
    test "attaches the authorization header", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", @route, fn conn ->
        {[header], _} = Enum.split_with(conn.req_headers, fn {key, _} -> key == "authorization" end)

        assert Kernel.elem(header, 1) =~ @options[:token]

        Plug.Conn.resp(conn, 200, "ok")
      end)

      options = Keyword.put(@options, :metrics, [Metrics.last_value("foo.bar")])

      Api.send(%{"foo:bar" => :rand.uniform(999)}, options)
    end

    test "logs when the request is successful", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", @route, fn conn ->
        Plug.Conn.resp(conn, 200, "ok")
      end)

      options = Keyword.put(@options, :metrics, [Metrics.last_value("foo.bar")])

      {:ok, log} = with_log(fn -> Api.send(%{"foo:bar" => :rand.uniform(999)}, options) end)

      assert log =~ "response_code=200"
    end

    test "logs when the request fails", %{bypass: bypass} do
      Bypass.down(bypass)

      options = Keyword.put(@options, :metrics, [Metrics.last_value("foo.bar")])

      {:ok, log} = with_log(fn -> Api.send(%{"foo:bar" => :rand.uniform(999)}, options) end)

      assert log =~ "error=failed_connect"
    end
  end
end
