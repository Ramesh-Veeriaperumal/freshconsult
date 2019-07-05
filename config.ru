 # This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment',  __FILE__)
# if defined?(PhusionPassenger)
#   PhusionPassenger.on_event(:starting_worker_process) do |forked|
#     if forked
#       require 'prometheus_exporter/instrumentation'
#       PrometheusExporter::Instrumentation::Process.start(type:"web")
#     else
#       # We're in direct spawning mode.
#     end
#   end
# end

run Helpkit::Application
