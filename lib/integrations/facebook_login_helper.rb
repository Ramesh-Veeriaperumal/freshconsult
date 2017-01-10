module Integrations
  module FacebookLoginHelper

  def create_user_for_sso nmobile
    account = (user_account.blank?) ? current_account : user_account
    account.make_current
    if @current_user.present? and @auth.present?
      if @current_user.deleted?
        @result.flash_message = I18n.t(:'flash.g_app.page_unavailable')
        return false
      end
      make_user_active
    elsif @current_user.present?
      @current_user.authorizations.create(:provider => provider, :uid => uid, :account_id => account.id) #Add an auth to existing user  
      make_user_active
    else  
      @new_auth = create_user_from_hash(account, nmobile) 
      if @new_auth
        @current_user = @new_auth.user
      else
        @result.flash_message = I18n.t(:'facebook.user_creation_failed')
        return false
      end
    end
    return true
  end

  private

    def set_redis_for_sso(account_id, user_id, provider)
      key_options = { :account_id => account_id, :user_id => user_id, :provider => provider}
      key_spec = Redis::KeySpec.new(Redis::RedisKeys::SSO_AUTH_REDIRECT_OAUTH, key_options)
      Redis::KeyValueStore.new(key_spec, curr_time, {:group => :integration, :expire => 300}).set_key
    end

    def random_hash
      random_hash = Digest::MD5.hexdigest(curr_time)  
    end

    def curr_time
      @curr_time ||= ((DateTime.now.to_f * 1000).to_i).to_s
    end

    def csrf_token_from_state_params
      @state_params["at"].present? ? @state_params["at"][0] : nil
    end

    def create_user_from_hash(account, nmobile)
      portal = account.portals.find_by_portal_url(requested_portal_url(nmobile))
      user = account.users.new  
      user.active = true
      user_params = { :user => {
        :name => fb_name,
        :email => fb_email ? fb_email : nil,
        :fd_profile_id => fb_profile_id.present? ? fb_profile_id : nil,
        :helpdesk_agent => false,
        :active => true,
        :language => portal ? portal.language : account.language
      }}
      unless user.signup!(user_params, nil, false)
        Rails.logger.error("user=>{:uid => #{uid}, :provider => #{provider}, :account_id => #{account.id}} \n Error occoured while creating user during facebook login. : \n#{user.errors.inspect}")
        return
      end
      auth = user.authorizations.create(:provider => provider, :uid => uid, :account_id => account.id)
      unless auth
        Rails.logger.error("user=>{:uid => #{uid}, :provider => #{provider}, :account_id => #{account.id}} \n Error occoured while creating authorization for user id #{user.id} during facebook login. \n#{user.errors.inspect}")
      end
      auth
    end

    def domain
      return URI.parse(@portal_url).host if @portal_url.present?
      Account.current.full_domain
    end
    

    def requested_portal_url nmobile
      if nmobile.present?
        @origin_account.full_domain
      else
        domain
      end
    end

    def fb_email
      @omniauth["info"]["email"]
    end

    def fb_name
      @omniauth["info"]["name"]
    end

    def uid
      @omniauth["uid"]
    end

    def fb_profile_id
      @omniauth["info"]["nickname"]
    end

    def provider
      @omniauth["provider"]
    end

    def portal_type
      return @state_params["portal_type"][0] if @state_params and @state_params["portal_type"]
      ""
    end

    def user_account
      @origin_account
    end

    def make_user_active
      @current_user.active = true
      @current_user.save!
    end

    def nmobile? param_var
      param_var[:format] == "nmobile"
    end
  end
end