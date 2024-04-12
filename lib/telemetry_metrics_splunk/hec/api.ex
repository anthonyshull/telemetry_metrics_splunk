defmodule TelemetryMetricsSplunk.Hec.Api do
  @moduledoc """
  Sends metrics to the Splunk HTTP Event Collector (HEC).
  """

  require Logger

  @https_options [
    ssl: [
      verify: :verify_none
    ]
  ]

  @doc """
  Sends metrics to the Splunk HTTP Event Collector (HEC).

  You must include the Splunk URL and Token in the options.
  Metadata is optional and gets sent as dimensions.
  """
  @spec send(map(), TelemetryMetricsSplunk.options(), map()) :: :ok
  def send(measurements, options, metadata \\ %{})

  def send(measurements, [metrics: _, token: token, url: url], metadata) do
    fields = Map.merge(measurements, metadata)

    data =
      %{event: "metric", time: :erlang.system_time(:millisecond)}
      |> Map.put(:fields, fields)
      |> Jason.encode!()

    headers = [{~c"authorization", String.to_charlist("Splunk " <> token)}]

    response = :httpc.request(:post, {String.to_charlist(url), headers, ~c"application/json", data}, @https_options, [])

    case response do
      {:ok, result} ->
        Logger.debug("#{__MODULE__} response_code=#{result |> elem(0) |> elem(1)}")

      {:error, reason} ->
        Logger.warning("#{__MODULE__} error=#{elem(reason, 0)}")
    end
  end

  def send(measurements, [token: token, url: url], metadata) do
    send(measurements, [metrics: [], token: token, url: url], metadata)
  end
end
