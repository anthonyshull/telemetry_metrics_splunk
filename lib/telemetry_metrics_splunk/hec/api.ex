defmodule TelemetryMetricsSplunk.Hec.Api do
  @moduledoc false

  require Logger

  def send(measurements, metrics: _, url: url, token: token) do
    data =
      measurements
      |> Map.put(:time, :erlang.system_time(:millisecond))
      |> Map.put(:event, "metric")
      |> Jason.encode!()

    headers = [{~c"authorization", String.to_charlist("Splunk " <> token)}]

    response = :httpc.request(:post, {String.to_charlist(url), headers, ~c"application/json", data}, [], [])

    case response do
      {:ok, result} ->
        Logger.debug("#{__MODULE__} response_code=#{result |> elem(0) |> elem(1)}")

      {:error, reason} ->
        Logger.warning("#{__MODULE__} error=#{elem(reason, 0)}")
    end
  end
end
