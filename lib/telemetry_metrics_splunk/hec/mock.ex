defmodule TelemetryMetricsSplunk.Hec.Mock do
  use Plug.Router

  plug Plug.Parsers, parsers: [:json], pass: ["application/json"], json_decoder: Jason
  plug :match
  plug :dispatch

  post "/services/collector" do
    Plug.Conn.send_resp(conn, 200, Jason.encode!("ok"))
  end
end
