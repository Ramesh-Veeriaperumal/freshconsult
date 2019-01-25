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
  c.tracer sampler: sampler, enabled: true
end