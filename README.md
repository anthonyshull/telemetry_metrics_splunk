# TelemetryMetricsSplunk

:rotating_light: This library is in alpha :rotating_light:

`Telemetry.Metrics` reporter for Splunk metrics indexes using the Splunk HTTP Event Collector (HEC).

## Usage

```elixir
alias Telemetry.Metrics

children = [
  {Finch, name: MyFinch},
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

## Installation

Add `telemetry_metrics_splunk` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:telemetry_metrics_splunk, "0.0.3-alpha"}
  ]
end
```
