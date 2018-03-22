class Middleware::BatchApiRateLimiter
 
  def initialize(app)
    @app = app
  end

  def call(env)
    @app.call(env).tap do |r| 
      CustomRequestStore.store[:extra_credits] += r.length - 1
    end
    
  end
end
