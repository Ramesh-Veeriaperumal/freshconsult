module Integrations::GoogleGadgetHelper
  include Redis::RedisKeys
  include Redis::OthersRedis

  private
    def google_gadget_auth state_params, user_email, uid
      gv_id_hash = state_params["gv_id"][0]
      domain_user = @origin_account.user_emails.user_for_email(user_email)
      verify_gadget_user(domain_user)
      verify_gadget_viewer_id(@origin_account.id, gv_id_hash, domain_user) if @gadget_error.blank?
    end

    def verify_gadget_user user
      if user.blank?
        @gadget_error = true
        @notice = I18n.t('flash.gmail_gadgets.user_missing')
      end
    end

    def verify_gadget_viewer_id account_id, viewer_id_hash, user
      google_viewer_id = google_viewer_id_from_hash(account_id, viewer_id_hash)
      if google_viewer_id.present?
        set_agent_google_viewer_id(google_viewer_id, user)
      else
        @gadget_error = true
        @notice = I18n.t('flash.gmail_gadgets.kvp_missing')
      end
    end

    def set_agent_google_viewer_id google_viewer_id, user
      agent = user.agent
      if agent.present?
        agent.google_viewer_id = google_viewer_id
        agent.save!
      else
        @gadget_error = true
        @notice = I18n.t('flash.gmail_gadgets.agent_missing')
      end
    end

    def google_viewer_id_from_hash account_id, hash
      key_options = {:account_id => account_id, :token => hash}
      kv_store = Redis::KeyValueStore.new(Redis::KeySpec.new(GADGET_VIEWERID_AUTH, key_options))
      kv_store.group = :integration
      kv_store.get_key
    end
end