defmodule TelemetryMetricsSplunk do
  @moduledoc """
  `Telemetry.Metrics` reporter for Splunk metrics indexes using the Splunk HTTP Event Collector (HEC).

  > **NOTE** All options are required and the order is enforced: `metrics`, `token`, `url`.

  You can start the reporter with the `start_link/1` function:

    alias Telemetry.Metrics

    TelemetryMetricsSplunk.start_link(
      metrics: [
        Metrics.counter("foo.bar.baz")
      ],
      token: "00000000-0000-0000-0000-000000000000",
      url: "https://splunk.example.com:8088"
    )

  In production, you should use a Supervisor in your application definition:

    alias Telemetry.Metrics

    children = [
      {
        TelemetryMetricsSplunk, [
          metrics: [
            Metrics.counter("foo.bar.baz")
          ],
          token: "00000000-0000-0000-0000-000000000000",
          url: "https://splunk.example.com:8088"
        ]
      }
    ]

    Supervisor.start_link(children, strategy: :one_for_one)

  Metric names are normalized so that calling `:telemetry.execute([:foo, :bar], %{baz: 1})` will send a metric named `foo.bar.baz.counter`
  if you have a metric defined as `Metrics.counter("foo.bar.baz")`.
  """

  require Logger

  use GenServer

  alias Telemetry.Metrics
  alias TelemetryMetricsSplunk.Hec.Api

  @type option :: {:metrics, [Metrics.t()]} | {:token, String.t()| {:url, String.t()}}
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

    alias Telemetry.Metrics

    TelemetryMetricsSplunk.start_link(
      metrics: [
        Metrics.counter("foo.bar.baz")
      ]
      token: "00000000-0000-0000-0000-000000000000",
      url: "https://splunk.example.com:8088",
    )
  """
  @spec start_link(options) :: GenServer.on_start()
  def start_link(options) do
    GenServer.start_link(__MODULE__, options)
  end

  @impl GenServer
  @spec init(options) :: {:ok, [{any(), any()}]}
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
  Handles a telemetry event by normalizing it and sending it to the Splunk HEC.
  """
  @spec handle_event(any(), any(), map(), options) :: :ok
  def handle_event(_event_name, measurements, metadata, options) do
    options
    |> Keyword.get(:metrics, [])
    |> Enum.map(&format_metric(&1, measurements))
    |> Map.new(fn {k, v} -> {k, v} end)
    |> Api.send(options, metadata)
  end

  defp format_metric(metric, measurements) do
    %{event_name: event_name, measurement: measurement} = metric

    measurements
    |> Map.get(measurement, 0.0)
    |> (fn value -> {format_measurement(event_name, measurement, metric), value} end).()
  end

  defp measurement_name(event) do
    event
    |> Atom.to_string()
    |> String.downcase()
  end

  defp metric_name(event_name) do
    event_name
    |> Enum.map_join(".", &Atom.to_string/1)
    |> String.downcase()
  end

  defp metric_type(struct) do
    struct.__struct__
    |> Atom.to_string()
    |> String.split(".")
    |> List.last()
    |> Recase.to_snake()
  end

  defp format_measurement(event_name, key, metric) do
    "metric_name:#{metric_name(event_name)}.#{measurement_name(key)}.#{metric_type(metric)}"
  end
end
