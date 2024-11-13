# TelemetryMetricsSplunk

[![Version](https://img.shields.io/hexpm/v/telemetry_metrics_splunk.svg)](https://hex.pm/packages/telemetry_metrics_splunk)

`Telemetry.Metrics` reporter for Splunk metrics indexes using the Splunk HTTP Event Collector (HEC).

## Installation

Add `telemetry_metrics_splunk` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:telemetry_metrics_splunk, "~> 0.0.0"}
  ]
end
```

## Usage

You can run the [demo project](https://github.com/anthonyshull/telemetry_metrics_splunk_demo) to see TelemetryMetricsSplunk in action.

```elixir
alias Telemetry.Metrics

children = [
  {Finch, name: MyFinch},
  {
    TelemetryMetricsSplunk, [
      finch: MyFinch,
      index: "main",
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
