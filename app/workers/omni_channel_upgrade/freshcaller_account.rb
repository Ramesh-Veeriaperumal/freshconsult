module OmniChannelUpgrade
  class FreshcallerAccount < BaseWorker
    sidekiq_options queue: :create_and_link_omni_account, retry: 0, backtrace: true

    include Freshcaller::Util
    include Freshcaller::AgentUtil
    include Billing::OmniSubscriptionUpdateMethods
    include OmniChannel::Util

    FRESHCALLER = 'freshcaller'.freeze

    def perform(args)
      args.symbolize_keys!
      account = Account.current
      raise 'Bundle id not present' if account.omni_bundle_id.blank?

      user = get_freshid_org_admin_user(account).make_current
      bundle_id = account.omni_bundle_id
      billing_response = args[:chargebee_response].deep_symbolize_keys
      create_and_link_omni_caller_account(account, user, bundle_id, billing_response)
    rescue StandardError => e
      Rails.logger.error "Error while creating omni bundle freshcaller account Account ID: #{account.id} Exception: #{e.message} :: #{e.backtrace[0..20].inspect}"
      NewRelic::Agent.notice_error(e, account_id: Account.current.id, args: args)
      raise e
    ensure
      User.reset_current_user
    end

    private

      def current_account
        Account.current
      end

      def create_and_link_omni_caller_account(account, user, bundle_id, billing_response)
        freshid_user = Freshid::V2::Models::User.find_by_email(user.email, account.organisation_domain)
        freshcaller_signup_response = create_and_activate_bundle_freshcaller_account(account, freshid_user, bundle_id, billing_response[:response][:subscription][:trial_end])
        freshcaller_signup_response['bundle_id'] = bundle_id
        freshcaller_account_domain = freshcaller_signup_response['account']['domain']
        freshcaller_misc_params = freshcaller_signup_response['misc'].is_a?(Hash) ? freshcaller_signup_response['misc'] : JSON.parse(freshcaller_signup_response['misc'])
        link_params = freshcaller_bundle_linking_params(account, user.email, user.single_access_token, freshcaller_signup_response)
        enable_freshcaller_agent(user, freshcaller_misc_params['user']['freshcaller_account_admin_id'])
        send_access_token_to_caller(freshcaller_account_domain, link_params)
        schedule_freshcaller_account_creation_callbacks(account, freshcaller_account_domain, billing_response, user.agent.id)
      end

      def schedule_freshcaller_account_creation_callbacks(account, freshcaller_account_domain, billing_response, performer_id)
        schedule_agent_sync_callback(performer_id, FRESHCALLER)
        schedule_bundle_updation_callback(account, freshcaller_account_domain)
        schedule_freshcaller_billing_callback(account.subscription.trial?, billing_response)
      end

      def schedule_freshcaller_billing_callback(is_trial, billing_response)
        message_uuid = Thread.current[:message_uuid]
        message_uuid = message_uuid.present? ? message_uuid.first : UUIDTools::UUID.timestamp_create.hexdigest
        subscription_event = get_subscription_event(is_trial)
        chargebee_result = construct_payload_for_conversion(billing_response[:response], message_uuid, subscription_event)
        Billing::FreshcallerSubscriptionUpdate.perform_in(10.seconds.from_now, chargebee_result)
      end
  end
end
