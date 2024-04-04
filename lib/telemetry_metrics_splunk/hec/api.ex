defmodule TelemetryMetricsSplunk.Hec.Api do
  @moduledoc """
  """

  def send(measurements, [metrics: _, url: url, token: token]) do
    data =
      measurements
      |> Map.put(:time, :erlang.system_time(:millisecond))
      |> Map.put(:event, "metric")
      |> Jason.encode!()

    headers = [{'authorization', String.to_charlist("Splunk " <> token)}]

    :httpc.request(:post, {String.to_charlist(url), headers, 'application/json', data}, [], [])
  end
end
