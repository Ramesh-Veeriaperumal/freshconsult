class Middleware::BatchApiRequestIdInjector
 
  def initialize(app)
    @app = app
  end

  def call(env)
    Rails.logger.push_tags(SecureRandom.uuid)
    @app.call(env).tap do |r| 
      r.headers['X-Request-Id'] = Rails.logger.pop_tags.first
    end
  end
end
