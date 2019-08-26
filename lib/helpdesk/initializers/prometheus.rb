unless Rails.env.test? || Rails.env.development?
  if (ENV['ENABLE_PROMETHEUS']=="1")
    require 'prometheus_exporter/middleware'
    require 'prometheus_exporter/instrumentation'

    # This reports stats per request like HTTP status and timings
    Rails.application.middleware.use PrometheusExporter::Middleware
    PrometheusExporter::Instrumentation::Process.start(type: "master")
  end
end
