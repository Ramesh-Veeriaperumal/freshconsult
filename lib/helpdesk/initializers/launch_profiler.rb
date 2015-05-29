if Rails.env.development?
  Helpkit::Application.configure do
    config.middleware.delete(Rack::MiniProfiler)
    config.middleware.insert_after(Middleware::LaunchProfiler, Rack::MiniProfiler)
  end
  Rack::MiniProfiler.config.backtrace_includes = [/^\/?(app|config|lib|test|api)/]
end
