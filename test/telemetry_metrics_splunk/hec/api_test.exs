defmodule TelemetryMetricsSplunk.Hec.ApiTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias TelemetryMetricsSplunk.Hec.Api

  @port 9999
  @route "/services/collector"
  @options [
    finch: TestFinch,
    token: "00000000-0000-0000-0000-000000000000",
    url: "http://localhost:#{@port}#{@route}"
  ]

  setup do
    bypass = Bypass.open(port: @port)

    finch = Finch.start_link(name: @options[:finch])

    {:ok, bypass: bypass, finch: finch}
  end

  describe "send/2" do
    test "attaches the authorization header", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", @route, fn conn ->
        {[header], _} = Enum.split_with(conn.req_headers, fn {key, _} -> key == "authorization" end)

        assert Kernel.elem(header, 1) =~ @options[:token]

        Plug.Conn.resp(conn, 200, "ok")
      end)

      Api.send(%{"metric_name:foo" => :rand.uniform(999)}, @options)
    end

    test "adds measurements to the payload", %{bypass: bypass} do
      metric = :rand.uniform(999)

      Bypass.expect_once(bypass, "POST", @route, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn, read_timeout: 500)
        data = Jason.decode!(body)

        assert data["fields"]["metric_name:foo"] == metric

        Plug.Conn.resp(conn, 200, "ok")
      end)

      Api.send(%{"metric_name:foo" => metric}, @options)
    end

    test "adds dimensions to the payload", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", @route, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn, read_timeout: 500)
        data = Jason.decode!(body)

        assert data["fields"]["foo"] == "bar"

        Plug.Conn.resp(conn, 200, "ok")
      end)

      Api.send(%{"metric_name:foo" => :rand.uniform(999)}, @options, %{"foo" => "bar"})
    end

    test "logs when the request is successful", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", @route, fn conn ->
        Plug.Conn.resp(conn, 200, "ok")
      end)

      {:ok, log} = with_log(fn -> Api.send(%{"foo" => :rand.uniform(999)}, @options) end)

      assert log =~ "status: 200"
    end

    test "logs when the request fails", %{bypass: bypass} do
      Bypass.down(bypass)

      {:ok, log} = with_log(fn -> Api.send(%{"foo" => :rand.uniform(999)}, @options) end)

      assert log =~ "reason: :econnrefused"
    end
  end
end
