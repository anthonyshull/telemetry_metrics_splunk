defmodule TelemetryMetricsSplunk do
  @moduledoc """
  Documentation for `TelemetryMetricsSplunk`.
  """

  require Logger

  use GenServer

  alias Telemetry.Metrics
  alias TelemetryMetricsSplunk.Hec.Api

  @type option ::
          {:url, String.t()}
          | {:token, String.t()}
          | {:metrics, [Metrics.t()]}
  @type options :: [option()]

  @doc """
  Reporter's child spec.

  This function allows you to start the reporter under a supervisor like this:

      children = [
        {TelemetryMetricsSplunk, options}
      ]

  See `start_link/1` for a list of available options.
  """
  @spec child_spec(options) :: Supervisor.child_spec()
  def child_spec(options) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [options]}}
  end

  @doc """
  Starts a reporter and links it to the calling process.

  ## Example

      alias Telemetry.Metrics

      TelemetryMetricsSplunk.start_link(
        url: "https://splunk.example.com:8088",
        token: "00000000-0000-0000-0000-000000000000",
        metrics: [
          Metrics.counter("foo.bar.baz")
        ]
      )
  """
  @spec start_link(options) :: GenServer.on_start()
  def start_link(options) do
    GenServer.start_link(__MODULE__, options)
  end

  @impl GenServer
  def init(options) do
    Process.flag(:trap_exit, true)

    options
    |> Keyword.fetch!(:metrics)
    |> Enum.group_by(& &1.event_name)
    |> Map.keys()
    |> Enum.each(fn event ->
      :telemetry.attach({__MODULE__, event, self()}, event, &__MODULE__.handle_event/4, options)
    end)

    {:ok, options}
  end

  @impl GenServer
  def terminate(_, events) do
    for event <- events do
      :telemetry.detach({__MODULE__, event, self()})
    end

    :ok
  end

  @doc """
  Handles a telemetry event by sending it to the Splunk HTTP Event Collector.

  A metric like `Metrics.last_value("foo.bar.baz")` will be converted.
  `foo_bar:baz` will be sent to Splunk where `foo_bar` is the metric name and `baz` is the dimension name.
  This lines up with the telemetry execution of `:telemetry.execute([:foo, :bar], %{baz: 123})`.
  """
  def handle_event(event_name, measurements, _metadata, options) do
    measurements
    |> Map.new(fn {k, v} -> {format_measurement(event_name, k), v} end)
    |> Api.send(options)
  end

  defp dimension_name(event) do
    event
    |> Atom.to_string()
    |> String.replace(~r/_|\s/, ".")
    |> String.downcase()
  end

  defp metric_name(event_name) do
    event_name
    |> Enum.map(&Atom.to_string/1)
    |> Enum.join("_")
    |> String.downcase()
  end

  defp format_measurement(event_name, key) do
    "#{metric_name(event_name)}:#{dimension_name(key)}"
  end
end
