module Freshid::V2::EventProcessorExtensions
  ACCOUNT_ORGANISATION_MAPPED = :ACCOUNT_ORGANISATION_MAPPED
  SUCCESS = 200..299

  def initialize(params)
    initialize_attributes(params)
  end

  def user_active?(user)
    ###### Overridden ######
    user.active_and_verified?
  end

  def fetch_user_by_uuid(uuid)
    ###### Overridden ######
    Account.current.all_technicians.find_by_freshid_uuid(uuid)
  end

  def post_migration(account, event_type=nil)
    return if ( event_type != ACCOUNT_ORGANISATION_MAPPED || account.freshid_org_v2_enabled? )
    account.rollback(:freshid)
    account.launch_freshid_with_omnibar(true)
    migrate_to_freshconnect(account)
  end

  def migrate_to_freshconnect(account)
    return unless account.falcon_enabled? && account.freshconnect_account.nil?
    begin
      if account.collab_settings.nil?
        Freshconnect::RegisterFreshconnect.perform_async
        Rails.logger.info("FRESHID V2 MIGRATION: a=#{account.id}, freshconnect account creation success")
      else
        freshconnect_flag = account.has_feature?(:collaboration)
        actual_response = do_migrate_freshconnect(freshconnect_flag, account)
        response_code = actual_response.code
        if SUCCESS.include?(response_code)
          response = JSON.parse(actual_response.body)
          response = response.deep_symbolize_keys
          fresh_connect_acc = Freshconnect::Account.new(account_id: account.id,
                                                        product_account_id: response[:product_account_id],
                                                        enabled: false,
                                                        freshconnect_domain: response[:domain])
          fresh_connect_acc.save!
          account.add_feature(:freshconnect)
          if account.save
            CollabPreEnableWorker.perform_async(false)
            account.revoke_feature(:collaboration)
            Rails.logger.info("FRESHID V2 MIGRATION: a=#{account.id},r=#{response} freshconnect account creation success")
          else
            Rails.logger.info("FRESHID V2 MIGRATION: a=#{account.id},r=#{response} freshconnect account creation error")
          end
        else
          Rails.logger.info("FRESHID V2 MIGRATION: a=#{account.id},r=#{response} freshconnect account creation error")
        end
      end
    rescue Exception => e
      Rails.logger.info("FRESHID V2 MIGRATION: a=#{account.id}, freshconnect account creation error #{e.message}, #{e.backtrace}")
    end
  end

  def do_migrate_freshconnect(fc_enabled, account)
    payload = { domain: account.full_domain,
                account_id: account.id.to_s,
                enabled: fc_enabled,
                fresh_id_version: Freshid::V2::Constants::FRESHID_SIGNUP_VERSION_V2,
                organisation_id: account.organisation_from_cache.try(:organisation_id),
                organisation_domain: account.organisation_from_cache.try(:domain) 
              }.to_json
    RestClient::Request.execute(
      method: :post,
      url: "#{CollabConfig['freshconnect_url']}/migrate/account",
      payload: payload,
      headers: {
        'Content-Type' => 'application/json',
        'ProductName' => 'freshdesk',
        'Authorization' => collab_request_token
      }
    )
  end

  def collab_request_token
    @request_token ||= JWT.encode(
      {
        ProductAccountId: '',
        IsServer: '1'
      }, CollabConfig['secret_key']
    )
  end

  # Only freshid default sso authentication_module_updated event has to be consumed.
  def authentication_module_updated_event_callback(payload)
    ###### Overridden ######
    if current_account.freshid_sso_sync_enabled? &&
        (payload[:authentication_module][:type]) &&
        default_auth_module?(payload[:authentication_module])
      update_default_sso_event(payload[:authentication_module])
      Rails.logger.info 'Processed freshid default sso config'
    else
      Rails.logger.info "Skipping authentication_module_updated event. sso type #{payload[:authentication_module][:type]} : entrypoint_id #{payload[:authentication_module][:entrypoint_id]} : sync feature #{Account.current.freshid_sso_sync_enabled?}"
    end
  end

  # freshid entrypoint events
  def entrypoint_created_event_callback(payload)
    ###### Overridden ######
    update_accounts(payload)
  end

  def entrypoint_updated_event_callback(payload)
    ###### Overridden ######
    update_accounts(payload)
  end

  def entrypoint_deleted_event_callback(payload)
    ###### Overridden ######
    update_accounts(payload)
  end

  def self.prepended(base)
    class << base
      prepend ClassMethods
    end
  end

  module ClassMethods
    def process_later(args)
      ###### Overridden ######
      Freshid::V2::ProcessEvents.perform_async args
    end
  end

  private

    # Custom freshid security settings
    # Enumerate the entrypoint accounts to update the sso modules
    def update_accounts(params)
      account_ids = []

      if freshid_custom_sso_event?(params[:entrypoint][:modules]) && params[:entrypoint][:accounts].present?
        Rails.logger.info 'Starting to process entrypoint sso config'
        params[:entrypoint][:accounts].each do |freshid_account|
          next unless freshid_account[:product_id].eql? FRESHID_V2_PRODUCT_ID.to_s
          Rails.logger.info 'Fresdesk account is present to be processed'
          account_domain = freshid_account[:domain]
          raise 'domain in freshid account params is empty' if account_domain.nil?
          domain_mapping = DomainMapping.find_by_domain(account_domain)
          raise "domain_mapping is not present for this domain #{account_domain}" unless domain_mapping.present?
          account_id = domain_mapping.account_id

          fetch_account(account_id) do
            Rails.logger.info "Freshid sso sync feature enabled? #{current_account.freshid_sso_sync_enabled?}"
            next unless current_account.freshid_sso_sync_enabled?

            account_ids << account_id
            if @event_type.downcase == 'entrypoint_deleted'
              process_entrypoint_deleted_event(
                  scrape_sso_changes(params[:entrypoint][:modules]),
                  params[:entrypoint][:user_type])
            else
              process_custom_freshid_sso_events(
                  scrape_sso_changes(params[:entrypoint][:modules]),
                  entrypoint_attrs(params[:entrypoint]),
                  params[:entrypoint][:user_type])
            end
          end
        end
      end
      Rails.logger.info "Updated accounts of the entrypoint event - accounts :#{account_ids.inspect}"
      account_ids
    rescue StandardError => e
      Rails.logger.error "Error while updating entrypoint event #{params[:event_type]} : org #{params[:organisation_id]} : entry id #{params[:entrypoint_id]}"
    end

    # auth modules will contain password, google, sso
    def scrape_sso_changes(auth_modules)
      auth_modules.select {|auth_module| freshid_sso_event?(auth_module[:type]) }
    end

    def entrypoint_attrs(entrypoint_payload)
      {
          entrypoint_url:   entrypoint_payload[:entrypoint_url],
          entrypoint_id:    entrypoint_payload[:entrypoint_id],
          entrypoint_title: entrypoint_payload[:title]
      }
    end

    def fetch_account(account_id)
      Sharding.admin_select_shard_of(account_id) do
        account = Freshid.account_class.find(account_id).make_current
        yield
      end
    rescue Exception => e
      log_error(e, account_id: account_id)
    ensure
      Freshid.account_class.reset_current_account
    end

    def process_custom_freshid_sso_events(auth_modules, entrypoint_hash, user_type)
      auth_modules.each { |auth_module| update_custom_sso_event(auth_module[:enabled], user_type, entrypoint_hash) }
    end

    def process_entrypoint_deleted_event(auth_modules, user_type)
      # Though the entrypoint event is deleted, the auth modules inside this event will have enabled as true/false because
      # freshid doesn't delete the authmodule(in our case sso module) associated with the entrypoint before sending the entrypoint
      # deleted event. So we need to handle it here.
      auth_modules.each { |auth_module| update_custom_sso_event(false, user_type) }
    end

    def update_custom_sso_event(enable, user_type, entrypoint_hash = {})
      Rails.logger.info "update_custom_sso_event called for user_type - #{user_type}, toggle method #{enable}"
      if enable
        current_account.safe_send(
            "enable_#{user_type.downcase}_custom_sso!",
            entrypoint_hash.merge(logout_redirect_url: "https://#{current_account.full_domain}")
        )
      else
        current_account.safe_send("disable_#{user_type.downcase}_custom_sso!")
      end
    end

    def freshid_custom_sso_event?(auth_modules)
      scrape_sso_changes(auth_modules).present?
    end

    ##### Default freshid security settings (Only user type is agent)
    def freshid_sso_event?(module_type)
      SsoUtil::FRESHID_SSO_EVENT_TYPES.include?(module_type)
    end

    # AUTHENTICATION_MODULE_UPDATED events will be triggered for both default and custom sso config. we are consuming
    # this event only for default config. We consume entrypoint events for custom sso config as it has the associated required attributes.
    def default_auth_module?(auth_module)
      auth_module[:entrypoint_id].nil?
    end

    def update_default_sso_event(auth_module_payload)
      Rails.logger.debug "update_default_sso_event called for type - #{SsoUtil::FRESHID_SSO_METHOD_MAP[auth_module_payload[:type]]}, toggle method #{auth_module_payload[:enable]}"
      if auth_module_payload[:enable]
        current_account.safe_send(
            "enable_agent_#{SsoUtil::FRESHID_SSO_METHOD_MAP[auth_module_payload[:type]]}_sso!",
            "https://#{current_account.full_domain}"
        )
      else
        current_account.safe_send(
            "disable_agent_#{SsoUtil::FRESHID_SSO_METHOD_MAP[auth_module_payload[:type]]}_sso!"
        )
      end
    end

    def current_account
      Account.current
    end
end
