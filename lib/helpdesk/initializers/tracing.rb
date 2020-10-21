# frozen_string_literal: true

if TracingConfig['enabled']

  def fetch_configurator_options
    exporter = nil
    logger = nil

    if Rails.env.development? || Rails.env.test?
      exporter = OpenTelemetry::SDK::Trace::Export::ConsoleSpanExporter.new
      require 'custom_logger'
      logger = CustomLogger.new(Rails.root.join('log', 'tracing.log'))
    else
      exporter = OpenTelemetry::Exporter::OTLP::Exporter.new(
        endpoint: "#{TracingConfig['tracing_host']}:#{TracingConfig['tracing_host_port']}#{TracingConfig['otlp_tracing_path']}",
        insecure: true
      )
      logger = Rails.logger
    end

    multispan_exporter = OpenTelemetry::SDK::Trace::Export::MultiSpanExporter.new(
      [exporter]
    )

    {
      'logger'         => logger,
      'sampler'        => OpenTelemetry::SDK::Trace::Samplers.parent_based(
        root: OpenTelemetry::SDK::Trace::Samplers.trace_id_ratio_based(
          TracingConfig['sampler_probability']
        )
      ),
      'span_processor' => OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
        exporter: multispan_exporter,
        max_export_batch_size: TracingConfig['span_batch_size']
      )
    }
  end

  host_ip = Socket.ip_address_list.detect(&:ipv4_private?).try(:ip_address)
  configurator_options = fetch_configurator_options

  OpenTelemetry::SDK.configure do |c|
    c.logger = configurator_options['logger']

    c.use 'OpenTelemetry::Instrumentation::Rails'
    c.use 'OpenTelemetry::Instrumentation::Rack'
    c.use 'OpenTelemetry::Instrumentation::ActionPack'
    c.use 'OpenTelemetry::Instrumentation::Mysql2'
    c.use 'OpenTelemetry::Instrumentation::Redis'
    c.use 'OpenTelemetry::Instrumentation::Dalli'
    c.use 'OpenTelemetry::Instrumentation::Ethon'
    c.use 'OpenTelemetry::Instrumentation::Net::HTTP'

    c.add_span_processor(configurator_options['span_processor'])
    # TODO: Based on runtime -
    # Append `_{web/sidekiq/rake/shoryuken}` to TracingConfig['service_name']
    c.resource = OpenTelemetry::SDK::Resources::Resource.create(
      'host.ip' => host_ip,
      'host.name' => TracingConfig['host_name'],
      'service.name' => TracingConfig['service_name']
    )
    c.tracer_provider.active_trace_config = OpenTelemetry::SDK::Trace::Config::TraceConfig.new(
      sampler: configurator_options['sampler']
    )
  end
end
