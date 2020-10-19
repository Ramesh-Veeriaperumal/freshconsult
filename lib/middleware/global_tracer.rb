class Middleware::GlobalTracer
  require 'datadog/statsd'

  DATADOG_CONFIG = YAML::load_file(File.join(Rails.root, 'config', 'datadog.yml'))

  def initialize(app, options = {})
    @app = app
  end

  def call(env)
    begin
      statsd = Datadog::Statsd.new DATADOG_CONFIG["dd_agent_host"], DATADOG_CONFIG["dogstatsd_port"]
      if  env['HTTP_X_REQUEST_START']
        a = env['HTTP_X_REQUEST_START'][2, env['HTTP_X_REQUEST_START'].length].to_f
        b = Time.now.to_f.round(3)
        statsd.distribution('helpkit.web.queue.wait.time', b-a)
      end
    rescue Exception => e
      NewRelic::Agent.notice_error(e,{:description => "Middleware Global trace error"})
    ensure
      @status, @headers, @response =  @app.call(env)
      ::NewRelic::Agent.add_custom_attributes(requestId: env['HTTP_X_REQUEST_ID'], appVersion: ENV['APP_VERSION'])
      return [@status, @headers, @response]
    end
  end
end
