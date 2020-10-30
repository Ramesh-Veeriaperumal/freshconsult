class Auth::TwitterAuthenticator < Auth::Authenticator
  include Integrations::TwitterLoginHelper
  include Helpdesk::Permission::User

  def after_authenticate(params)
    user_account.make_current
    begin
      unless user_account.blank?
        @current_user = user_account.user_emails.user_for_email(twitter_email) if twitter_email.present?
        @auth = Authorization.find_from_hash(@omniauth, user_account.id)
        @current_user = user_account.all_users.find_by_twitter_id(twitter_id) if @current_user.blank? and twitter_id.present?
        return twitter_invalid_redirect if !@current_user and !has_login_permission?(twitter_email, user_account)
        if create_user_for_sso
          set_redis_for_sso(user_account.id, @current_user.id, @omniauth['provider'])
          @result.redirect_url = get_redirect_url
        else
          @result.redirect_url = @portal_url
        end
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      @result.redirect_url = @portal_url
    end
    @result
  end

  def register_middleware(omniauth)
    omniauth.provider(
      :twitter,
      TwitterConfig::CLIENT_ID, #twitter is in twitter.yml
      TwitterConfig::CLIENT_SECRET, #twitter is in twitter.yml
      :setup => lambda { |env|
        unless env["PATH_INFO"].split("/")[3] == "callback"
          raise "Twitter Signin Feature is not enabled for this account." unless twitter_signin_enabled?(env['QUERY_STRING'])
          env['omniauth.strategy'].options[:state] = construct_state_params(env) 
        end
      },
      :authorize_options => [:scope, :display, :state, :redirect_uri],
      :redirect_uri => "#{AppConfig['integrations_url'][Rails.env]}/auth/twitter/callback"
    )
  end

  private
    def twitter_signin_enabled?(query_string)
      Rails.logger.info "Twitter Authenticator - Query string = #{query_string.inspect}"
      query = Rack::Utils.parse_query(query_string)
      Rails.logger.info "Twitter Authenticator - Query = #{query.inspect}"
      account_id = Rack::Utils.parse_query(query["origin"])["id"]
      Rails.logger.info "Twitter Authenticator - Account ID = #{account_id}"
      flag = false
      Sharding.select_shard_of(account_id) do
        account = Account.find(account_id)
        account.make_current
        flag = account.features?(:twitter_signin)
      end
      flag
    end

    def get_redirect_url
      twitter_url + "/sso/login?provider=twitter&uid=#{uid}&s=#{random_hash}&at=#{csrf_token_from_state_params}"
    end

    def twitter_url
      portal_type.present? ? "#{user_account.url_protocol}://#{user_account.full_domain}" : @portal_url
    end

    def construct_state_params env
      query_string = Rack::Utils.parse_query(env['QUERY_STRING'])
      origin = Rack::Utils.parse_query(query_string['origin'])
      account_id = Rack::Utils.parse_query(query_string['origin'])['id']
      ecrypted_msg = get_ecrypted_msg(account_id, env['HTTP_HOST'])
      "portal_type%3D#{origin['portal_type']}%26identifier%3D#{ecrypted_msg}%26portal_domain%3D#{env['HTTP_HOST']}%26at%3D#{origin['token']}"
    end

    def twitter_invalid_redirect
      @result.redirect_url = "#{@portal_url}/support/login?restricted_helpdesk_login_fail=true"
      @result.invalid_nmobile = true
      @result
    end
end
