defmodule TelemetryMetricsSplunk do
  @moduledoc """
  `Telemetry.Metrics` reporter for Splunk metrics indexes using the Splunk HTTP Event Collector (HEC).

  You can start the reporter with the `start_link/1` function:

  ```elixir
    alias Telemetry.Metrics

    TelemetryMetricsSplunk.start_link(
      finch: MyFinch,
      metrics: [
        Metrics.summary("vm.memory.total")
      ],
      token: "00000000-0000-0000-0000-000000000000",
      url: "https://example.splunkcloud.com:8088/services/collector"
    )
  ```

  In production, you should use a Supervisor in your application definition:

  ```elixir
    alias Telemetry.Metrics

    children = [
      {
        Finch,
        name: MyFinch,
        pools: %{
          :default => [size: 10],
          "https://example.splunkcloud.com:8088" => [count: 2, size: 4]
        }
      },
      {
        TelemetryMetricsSplunk, [
          finch: MyFinch,
          metrics: [
            Metrics.summary("vm.memory.total")
          ],
          token: "00000000-0000-0000-0000-000000000000",
          url: "https://example.splunkcloud.com:8088/services/collector"
        ]
      }
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  ```

  Metric names are normalized so that calling `:telemetry.execute([:vm, :memory], %{total: 500})` will send a metric named `vm.memory.total.summary`
  if you have a metric defined as `Metrics.summary("vm.memory.total")`.
  """

  require Logger

  use GenServer

  alias Telemetry.Metrics
  alias TelemetryMetricsSplunk.Hec.Api

  @options_schema [
    finch: [
      type: :atom
    ],
    metrics: [
      type:
        {:list,
         {:or,
          [
            {:struct, Metrics.Counter},
            {:struct, Metrics.Distribution},
            {:struct, Metrics.LastValue},
            {:struct, Metrics.Sum},
            {:struct, Metrics.Summary}
          ]}},
      required: true
    ],
    token: [
      type: :string
    ],
    url: [
      type: :string
    ]
  ]

  @type options :: [
          finch: Finch.name() | nil,
          metrics: list(Metrics.t()),
          token: String.t() | nil,
          url: String.t() | nil
        ]

  @doc """
  Reporter's child spec.

  This function allows you to start the reporter under a supervisor like this:

  ```elixir
    children = [
      {TelemetryMetricsSplunk, options}
    ]
  ```

  See `start_link/1` for a list of available options.
  """
  @spec child_spec(options :: options()) :: Supervisor.child_spec()
  def child_spec(options) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [options]}}
  end

  @doc """
  Starts a reporter and links it to the calling process.

  ```elixir
    alias Telemetry.Metrics

    TelemetryMetricsSplunk.start_link(
      finch: MyFinch,
      metrics: [
        Metrics.summary("vm.memory.total")
      ]
      token: "00000000-0000-0000-0000-000000000000",
      url: "https://example.splunkcloud.com:8088/services/collector",
    )
  ```
  """
  @spec start_link(options :: options()) :: GenServer.on_start()
  def start_link(options) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  @impl GenServer
  @spec init(options :: options()) :: {:ok, options()} | {:error, term()}
  def init(options) do
    Process.flag(:trap_exit, true)

    case NimbleOptions.validate(options, @options_schema) do
      {:ok, validated_options} ->
        attach_to_metrics(validated_options)

        {:ok, validated_options}

      {:error, error} ->
        {:error, error}
    end
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
  @spec handle_event(atom(), map(), map(), options()) :: :ok
  def handle_event(_event_name, measurements, metadata, options) do
    {metrics, client_options} = Keyword.pop(options, :metrics, [])

    metrics
    |> Enum.map(&format_metric(&1, measurements))
    |> Map.new(fn {k, v} -> {k, v} end)
    |> Api.send(client_options, metadata)
  end

  defp attach_to_metrics(options) do
    options
    |> Keyword.get(:metrics)
    |> Enum.group_by(& &1.event_name)
    |> Map.keys()
    |> Enum.each(fn event ->
      Logger.notice(%{module: __MODULE__, subscription: event})

      :telemetry.attach({__MODULE__, event, self()}, event, &__MODULE__.handle_event/4, options)
    end)
  end

  defp format_measurement(event_name, key, metric) do
    "metric_name:#{metric_name(event_name)}.#{measurement_name(key)}.#{metric_type(metric)}"
  end

  defp format_metric(metric, measurements) do
    %{event_name: event_name} = metric
    measurement = Map.get(metric, :name) |> List.last()

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
end
