Helpkit::Application.configure do

  # This middleware will attempt to return the contents of a file's body from disk in the response. 
  # If a file is not found on disk, the request will be delegated to the application stack. 
  # This middleware is commonly initialized to serve assets from a server's `public/` directory.
  config.middleware.delete ActionDispatch::Static 

  # Adds response time header to response.
  config.middleware.delete Rack::Runtime

  # Callbacks for each request.
  config.middleware.delete ActionDispatch::Callbacks

  # Flash
  config.middleware.delete ActionDispatch::Flash

  # We are not allowing HEAD for CORS.
  config.middleware.delete ActionDispatch::Head

  # https://github.com/rack/rack/blob/master/lib/rack/conditionalget.rb
  # env['HTTP_IF_MODIFIED_SINCE'] or env['HTTP_IF_NONE_MATCH'] should be present in response headers, for this to work.
  config.middleware.delete Rack::ConditionalGet 

  # set_cache_buster sets "no-cache" header, which makes this middleware superfluous. 
  # Refer to https://github.com/rack/rack/blob/master/lib/rack/etag.rb for rationale.
  config.middleware.delete Rack::ETag
  
  # sets X-UA-Compatible header, used by browsers.
  config.middleware.delete ActionDispatch::BestStandardsSupport

  # Authentication
  config.middleware.delete OpenIdAuthentication

  # Authentication
  config.middleware.delete OmniAuth::Builder

  # A gem which helps you detect the users preferred language, 
  # as sent by the "Accept-Language" HTTP header. Used only in account create.
  config.middleware.delete HttpAcceptLanguage::Middleware
end