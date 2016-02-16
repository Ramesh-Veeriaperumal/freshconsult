class Middleware::MultilingualSolutionRouter
  
  include MemcacheKeys

  ACCEPTED_PATHS = ['/support/solutions', '/support/articles', 
      '/mobihelp/solutions', '/mobihelp/articles']

  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    begin
      if request.path_info.starts_with?(*ACCEPTED_PATHS)
        shard = ShardMapping.lookup_with_domain(request.host)
        return execute_request(env) if shard.nil?
        if LaunchParty.new.launched?(feature: :solutions_meta_read, account: shard.account_id)
          request.path_info = request.path_info.gsub(/(\A\/support|\A\/mobihelp)/) {|match| "#{match}/multilingual"}
          Rails.logger.debug "********** Using solutions_meta_read **********"
        end
      end
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
    end
    execute_request(env)
  end
  
  def execute_request(env)
    @status, @headers, @response = @app.call(env)
    [@status, @headers, @response]
  end
end
