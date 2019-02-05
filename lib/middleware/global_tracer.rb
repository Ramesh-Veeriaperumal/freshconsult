class Middleware::GlobalTracer
  require 'datadog/statsd'
  def initialize(app, options = {})
    @app = app
  end

  def call(env)
    begin
      statsd = Datadog::Statsd.new
      if  env['HTTP_X_REQUEST_START']
        a = env['HTTP_X_REQUEST_START'][2, env['HTTP_X_REQUEST_START'].length].to_f
        b = Time.now.to_f.round(3)
        statsd.distribution('helpkit.web.queue.wait.time', b-a)
      end
    rescue Exception => e
      NewRelic::Agent.notice_error(e,{:description => "Middleware Global trace error"})
    ensure
      return @app.call(env)
    end
  end
end