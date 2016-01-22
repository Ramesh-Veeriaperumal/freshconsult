class Middleware::MultilingualSolutionRouter
  
  include MemcacheKeys

  ACCEPTED_PATHS = ['/support/solutions', '/support/articles', 
      '/mobihelp/solutions', '/mobihelp/articles']

  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    shard = ShardMapping.lookup_with_domain(request.host)
    return execute_request(env) if shard.nil?
    Sharding.select_shard_of(shard.account_id) do
      meta_read = Account.find(shard.account_id).features_included?(:solutions_meta_read)
      if (meta_read && request.path_info.starts_with?(*ACCEPTED_PATHS))
        # Please take a look at this: http://www.rubydoc.info/gems/rack/Rack/Request#path-instance_method
        # The method "path" returns script_name(if there is any) + path_info
        # We are using path_info here as path doesn't have a setter method.
        request.path_info = request.path_info.gsub(/(\A\/support|\A\/mobihelp)/) {|match| "#{match}/multilingual"} 
      end
    end
    execute_request(env)
  end
  
  def execute_request(env)
    @status, @headers, @response = @app.call(env)
    [@status, @headers, @response]
  end
end
