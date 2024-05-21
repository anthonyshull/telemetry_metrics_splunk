defmodule TelemetryMetricsSplunk.Hec.Api do
  @moduledoc """
  Sends metrics to the Splunk HTTP Event Collector (HEC).

  ```elixir
  alias TelemetryMetricsSplunk.Hec.Api

  measurements = %{
    "vm.memory.total.summary" => 500
  }

  options = [
    finch: MyFinch,
    token: "00000000-0000-0000-0000-000000000000",
    url: "https://example.splunkcloud.com:8088/services/collector"
  ]

  metadata = %{
    "server" => "alpha"
  }

  Api.send(measurements, options, metadata)
  ```

  > **NOTE** Metadata is optional and gets sent as dimensions.
  """

  require Logger

  @type options :: [finch: Finch.name() | nil, token: String.t() | nil, url: String.t() | nil]

  @doc """
  Sends metrics to the Splunk HTTP Event Collector (HEC).

  If `finch`, `token`, or `url` are `nil`, the function will log the info and not send the metrics.
  """
  @spec send(measurements :: map(), options :: options(), metadata :: map()) :: :ok
  def send(measurements, options, metadata \\ %{})

  def send(measurements, [finch: nil, token: nil, url: nil], metadata) do
    create_payload(measurements, metadata)
    |> Map.put(:module, __MODULE__)
    |> Logger.info()
  end

  def send(measurements, [finch: _finch, token: nil, url: _url], metadata) do
    send(measurements, [finch: nil, token: nil, url: nil], metadata)
  end

  def send(measurements, [finch: _finch, token: _token, url: nil], metadata) do
    send(measurements, [finch: nil, token: nil, url: nil], metadata)
  end

  def send(measurements, [finch: nil, token: _token, url: _url], metadata) do
    send(measurements, [finch: nil, token: nil, url: nil], metadata)
  end

  def send(measurements, [finch: finch, token: token, url: url], metadata) do
    data = create_payload(measurements, metadata) |> Jason.encode!()

    headers = [
      {"authorization", "Splunk " <> token},
      {"content-type", "application/json"}
    ]

    response = Finch.build(:post, url, headers, data) |> Finch.request(finch)

    case response do
      {:ok, result} ->
        Logger.debug(%{module: __MODULE__, status: result.status})

      {:error, reason} ->
        Logger.error(%{module: __MODULE__, reason: reason})
    end
  end

  def send(measurements, _options, metadata) do
    send(measurements, [finch: nil, token: nil, url: nil], metadata)
  end

  defp create_payload(measurements, metadata) do
    %{
      event: "metric",
      fields: Map.merge(measurements, metadata),
      time: :erlang.system_time(:millisecond)
    }
  end
end
