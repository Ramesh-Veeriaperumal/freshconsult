DATADOG_CONFIG = YAML::load_file(File.join(Rails.root, 'config', 'datadog.yml'))
datadog_enabled = DATADOG_CONFIG["enable"]

if datadog_enabled
  require 'aws-sdk'
  require 'dalli'
  require 'ddtrace'
  require 'net/http'
  require 'redis'
  require 'faraday'

  sampler = Datadog::RateSampler.new(1)
  Datadog.configure do |c|
    c.use :rails, { 'distributed_tracing' => 'true' }
    c.use :aws
    c.use :concurrent_ruby
    c.use :dalli
    c.use :http, { 'distributed_tracing' => 'true' }
    c.use :redis
    c.use :shoryuken
    c.use :rack, { 'distributed_tracing' => 'true' }
    c.use :sidekiq
    c.use :faraday, { 'distributed_tracing' => 'true' }
    c.tracer sampler: sampler, enabled: true, hostname: DATADOG_CONFIG["dd_agent_host"], port: DATADOG_CONFIG["dd_apm_port"]
  end
end