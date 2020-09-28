class OmniChannelUpgrade::FreshchatAccount < BaseWorker
  include Freshchat::JwtAuthentication
  include Freshchat::Util
  include Freshchat::AgentUtil
  include Billing::OmniSubscriptionUpdateMethods
  include OmniChannel::Util
  include OmniChannel::Constants
  include Redis::Keys::Others
  include Redis::OthersRedis

  sidekiq_options queue: :create_and_link_omni_account, retry: 0, backtrace: true

  def perform(args)
    args.symbolize_keys!
    account = Account.current
    raise 'Bundle id not present' if account.omni_bundle_id.blank?

    user = get_freshid_org_admin_user(account).make_current
    agent = user.agent
    billing_response = args[:chargebee_response].deep_symbolize_keys
    action_type = args[:type]
    if action_type == PRODUCT_OMNI_UPGRADE
      freshchat_account = create_new_freshchat_bundle_account(account, user, billing_response)
      launch_dependent_features(account)
      update_agent_chat_settings(account, agent)
      update_access_token(account.domain, user.single_access_token, freshchat_account, freshchat_jwt_token)
    elsif action_type == CHARGEBEE_OMNI_UPGRADE
      freshchat_account = account.freshchat_account
      launch_dependent_features(account)
      update_agent_chat_settings(account, agent)
      move_to_bundle_callbacks(account, user)
    end
    freshchat_domain = freshchat_account.domain
    schedule_freshchat_account_creation_callbacks(account, freshchat_domain, billing_response, agent.id, action_type)
  rescue StandardError => e
    Rails.logger.error "Error while creating omni Freshchat account Account ID: #{account.id} Exception: #{e.message} :: #{e.backtrace[0..20].inspect}"
    NewRelic::Agent.notice_error(e, account_id: Account.current.id, args: args)
    raise e
  ensure
    User.reset_current_user
  end

  private

    def create_new_freshchat_bundle_account(account, user, billing_response)
      freshid_user = Freshid::V2::Models::User.find_by_email(user.email, account.organisation.domain)
      request_body = bundle_signup_params(account, freshid_user, account.omni_bundle_id, billing_response[:response][:subscription][:trial_end])
      signup_response = signup_omni_account(OmniChannelBundleConfig['freshchat_signup_url'], request_body, FRESHCHAT)
      freshchat_response = signup_response['product_signup_response']
      raise 'Unsuccessful response on Freshchat account signup' unless freshchat_response.present? && freshchat_response['account'].present?

      app_info = freshchat_response['misc']['userInfoList'][0]
      freshchat_domain = freshchat_response['account']['domain']
      freshchat_account = account.create_freshchat_account(app_id: app_info['appId'], portal_widget_enabled: false,
                                                           token: app_info['webchatId'], enabled: true,
                                                           domain: freshchat_domain)
      freshchat_account
    end

    def move_to_bundle_callbacks(account, user)
      move_freshchat_to_bundle(account.omni_bundle_id, account.freshchat_account, freshchat_jwt_token)
      worker_args = {
        product_name: FRESHCHAT,
        params: {
          access_token: user.single_access_token
        }
      }
      OmniChannelUpgrade::LinkAccount.perform_async(worker_args)
    end

    def launch_dependent_features(account)
      [:emberize_agent_form, :emberize_agent_list, :omni_chat_agent].each do |feature|
        account.launch(feature) unless account.launched?(feature)
      end
    end

    def update_agent_chat_settings(account, agent)
      if account.omni_chat_agent_enabled? && agent.additional_settings.try(:[], :freshchat).nil?
        additional_settings = agent.additional_settings || {}
        additional_settings[:freshchat] = { enabled: true }
        agent.update_attribute(:additional_settings, additional_settings)
      end
    end

    def schedule_freshchat_account_creation_callbacks(account, freshchat_domain, billing_response, performer_id, action_type)
      schedule_agent_sync_callback(performer_id, FRESHCHAT)
      schedule_bundle_updation_callback(account, freshchat_domain)
      schedule_freshchat_billing_callback(account.subscription.trial?, billing_response, action_type)
    end

    def schedule_freshchat_billing_callback(is_trial, billing_response, action_type)
      if action_type == PRODUCT_OMNI_UPGRADE
        message_uuid = Thread.current[:message_uuid]
        message_uuid = message_uuid.present? ? message_uuid.first : UUIDTools::UUID.timestamp_create.hexdigest
        subscription_event = get_subscription_event(is_trial)
        chargebee_result = construct_payload_for_conversion(billing_response[:response], message_uuid, subscription_event)
        Billing::FreshchatSubscriptionUpdate.perform_in(10.seconds.from_now, chargebee_result)
      elsif action_type == CHARGEBEE_OMNI_UPGRADE
        Billing::FreshchatSubscriptionUpdate.perform_in(10.seconds.from_now, billing_response)
      end
    end
end
