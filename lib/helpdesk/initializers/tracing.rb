# frozen_string_literal: true

if TracingConfig['enabled']
  host_ip = Socket.ip_address_list.detect(&:ipv4_private?).try(:ip_address)

  jaeger_exporter = OpenTelemetry::Exporters::Jaeger::Exporter.new(
    service_name: TracingConfig['service_name'],
    host: TracingConfig['tracing_host'],
    port: TracingConfig['tracing_host_port']
  )
  multispan_exporter = OpenTelemetry::SDK::Trace::Export::MultiSpanExporter.new(
    [jaeger_exporter]
  )
  span_processor = OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
    exporter: multispan_exporter,
    max_export_batch_size: TracingConfig['span_batch_size']
  )

  OpenTelemetry::SDK.configure do |c|
    if Rails.env.development? || Rails.env.test?
      require 'custom_logger'
      c.logger = CustomLogger.new(Rails.root.join('log', 'tracing.log'))
    end

    c.use 'OpenTelemetry::Instrumentation::Rails'
    c.use 'OpenTelemetry::Instrumentation::Rack'
    c.use 'OpenTelemetry::Instrumentation::ActionPack'
    c.use 'OpenTelemetry::Instrumentation::ActiveSupport'
    c.use 'OpenTelemetry::Instrumentation::ActiveRecord'
    c.use 'OpenTelemetry::Instrumentation::Redis'
    c.use 'OpenTelemetry::Instrumentation::Dalli'
    c.use 'OpenTelemetry::Instrumentation::Ethon'
    c.use 'OpenTelemetry::Instrumentation::Net::HTTP'

    c.add_span_processor(span_processor)
    c.resource = OpenTelemetry::SDK::Resources::Resource.create(
      'host.ip' => host_ip, 'host.name' => TracingConfig['host_name']
    )
    c.tracer_provider.active_trace_config = OpenTelemetry::SDK::Trace::Config::TraceConfig.new(
      sampler: OpenTelemetry::SDK::Trace::Samplers.probability(
        TracingConfig['sampler_probability']
      )
    )
  end
end
