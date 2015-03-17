class GoogleSignupController < AccountsController
  include Redis::RedisKeys
  include Redis::OthersRedis
  include GoogleSignupHelper
  include GoogleOauth

  around_filter :select_shard
  skip_before_filter :check_privilege
  before_filter :initialize_user, :load_account, :only =>[:associate_google_account, :associate_local_to_google]
  before_filter :ensure_proper_protocol

  def associate_google_account
    oauth_user = @account.users.find_by_email(@email)
    if oauth_user.present?
      create_user_session(oauth_user) and return
    else
      render :associate_google
    end
  end

  def associate_local_to_google
    @account.make_current
    @check_session = @account.user_sessions.new(params[:user_session])
    if @check_session.save
      oauth_user = @check_session.user
      create_user_session(oauth_user) and return
    else
      render :associate_google
    end
  end

  private
    def select_shard(&block)
      if full_domain.blank?
        flash.now[:error] = t(:'flash.g_app.no_subdomain')
        render :signup_google and return
      end

      Sharding.select_shard_of(full_domain) do
        yield
      end
    end

    def initialize_user
      @name = params[:user][:name]
      @email = params[:user][:email]
      @uid = params[:user][:uid]
      @google_domain = params[:account][:google_domain]
    end

    def load_account
      @account = Account.find_by_full_domain(full_domain)
      if @account.nil?
        flash.now[:error] = t(:'flash.g_app.no_subdomain')
        render :signup_google_error and return
      end
    end

    def full_domain
      @full_domain ||= get_full_domain_for_google
    end

end