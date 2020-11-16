module Freshid::V2::EventProcessorExtensions
  ACCOUNT_ORGANISATION_MAPPED = :ACCOUNT_ORGANISATION_MAPPED
  SUCCESS = 200..299
  RAILS_LOGGER_PREFIX = 'FRESHID CUSTOM POLICY :: EVENT PROCESSOR EXTENSIONS :: '.freeze

  ORGANISATION_LIST_ACCOUNTS_PAGE_SIZE = 30

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
    return unless account.freshconnect_account.nil?

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

  def user_meta_info_event_callback
    Rails.logger.info "user_info for account is: #{@user_metadata.inspect} acc_id: #{Account.current.id}"
    return if @user_metadata[:userType] != 'CONTACT'

    user_info = @user_metadata[:userInfo]
    if user_info.class == String
      return unless valid_json?(user_info)

      user_info = JSON.parse(user_info).deep_symbolize_keys
    end
    assign_freshid_attributes_from_usermeta(formatted_user_data(user_info))
    @user.save if @user.changed? || @user.user_companies.any?(&:changed?)
  end

  def formatted_user_data(user_info)
    freshid_user_data = {}
    user_info.each_pair do |k, val|
      freshid_user_data[k] = (val.class == Array) ? val[0] : val
    end
    freshid_user_data
  end

  def assign_freshid_attributes_from_usermeta(freshid_user_data)
    first_name = get_first_match(freshid_user_data, SsoUtil::FIRST_NAME_STRS)
    last_name = get_first_match(freshid_user_data, SsoUtil::LAST_NAME_STRS)
    phone = get_first_match(freshid_user_data, SsoUtil::PHONE_NO_STRS)
    mobile = get_first_match(freshid_user_data, SsoUtil::MOBILE_NO_STRS)
    job_title = get_first_match(freshid_user_data, SsoUtil::TITLE_STRS)
    company = get_first_match(freshid_user_data, SsoUtil::COMPANY_NAME_STRS)
    # twitter_id = get_first_match(freshid_user_data, SsoUtil::TWITTER_ID_STRS)
    external_id = get_first_match(freshid_user_data, SsoUtil::EXTERNAL_ID_STRS)
    description = get_first_match(freshid_user_data, SsoUtil::DESCRIPTION_STRS)
    language = get_first_match(freshid_user_data, SsoUtil::LANGUAGE_STRS)
    time_zone = get_first_match(freshid_user_data, SsoUtil::TIMEZONE_STRS)

    name = "#{first_name} #{last_name}".strip
    @user.name = name if name.present?
    @user.phone = phone if phone.present?
    @user.mobile = mobile if mobile.present?
    @user.job_title = job_title if job_title.present?
    # @user.twitter_id = twitter_id if twitter_id.present?
    @user.assign_external_id(external_id) if external_id.present?
    @user.description = description if description.present?
    @user.assign_company(company) if company.present?
    @user.language = language if language.present? && (ContactConstants::LANGUAGES.include? language)
    @user.time_zone = time_zone if time_zone.present? && (ContactConstants::TIMEZONES.include? time_zone)
  end

  def get_first_match(freshid_user_data, keys)
    keys.each do |key|
      return freshid_user_data[key] if freshid_user_data.key?(key)
    end
    nil
  end

  def valid_json?(data)
    begin
      JSON.parse(data)
      return true
    rescue JSON::ParserError => e
      Rails.logger.info "Invalid data string in user_meta_info_event_callback acc_id: #{Account.current.id}"
      return false
    end
  end

  def fetch_user_for_update_events
    if @user_metadata.present? && @event_type == 'USER_META_INFO' && @user_metadata[:userType] == 'CONTACT' && @user_metadata[:email].present?
      Freshid.account_class.current.users.where(email: @user_metadata[:email]).first || Account.current.users.new(email: @user_metadata[:email])
    else
      Freshid::V2::LoginUtil.fetch_user_by_uuid(@user_uuid)
    end
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
      exclude_accounts = []
      if params[:entrypoint][:accounts].present?
        Rails.logger.info "#{RAILS_LOGGER_PREFIX} :: Starting to process entrypoint sso config"
        params[:entrypoint][:accounts].each do |freshid_account|
          next unless freshid_account[:product_id].eql? FRESHID_V2_PRODUCT_ID.to_s
          Rails.logger.info "#{RAILS_LOGGER_PREFIX} Fresdesk account is present to be processed"
          account_domain = freshid_account[:domain]
          raise 'domain in freshid account params is empty' if account_domain.nil?
          domain_mapping = DomainMapping.find_by_domain(account_domain)
          raise "domain_mapping is not present for this domain #{account_domain}" unless domain_mapping.present?
          account_id = domain_mapping.account_id

          fetch_account(account_id) do
            Rails.logger.info "Freshid sso sync feature enabled? #{current_account.freshid_sso_sync_enabled?}"
            next unless current_account.freshid_sso_sync_enabled?

            exclude_accounts << account_domain
            account_ids << account_id
            if @event_type.downcase == 'entrypoint_deleted'
              process_entrypoint_deleted_event(params[:entrypoint][:entrypoint_id])
            else
              process_freshid_custom_policy_events(params[:entrypoint])
            end
          end
        end
        remove_dangling_entrypoint(params[:entrypoint][:organisation_id], params[:entrypoint][:entrypoint_id], exclude_accounts)
      elsif params[:entrypoint][:modules] && params[:entrypoint][:organisation_id]
        remove_dangling_entrypoint(params[:entrypoint][:organisation_id], params[:entrypoint][:entrypoint_id], exclude_accounts)
      end
      Rails.logger.info "#{RAILS_LOGGER_PREFIX} Updated accounts of the entrypoint event - accounts :#{account_ids.inspect}"
      account_ids
    rescue StandardError => e
      Rails.logger.error "#{RAILS_LOGGER_PREFIX} Error while updating entrypoint event #{params[:event_type]} : org #{params[:organisation_id]} : entry id #{params[:entrypoint_id]}"
    end

    def remove_dangling_entrypoint(organisation_id, entrypoint_id, exclude_accounts)
      organsation_detail = Organisation.fetch_by_organisation_id(organisation_id)
      if organsation_detail
        Rails.logger.info "#{RAILS_LOGGER_PREFIX} Processing Dangling Entrypoint Removal for ORG #{organisation_id} "
        freshid_org_info = Freshid::V2::Models::Account.organisation_accounts(1, ORGANISATION_LIST_ACCOUNTS_PAGE_SIZE, organsation_detail.domain)
        if freshid_org_info
          Rails.logger.info "#{RAILS_LOGGER_PREFIX} Dangling Entrypoint Removal :: ORG #{organisation_id} :: TOTAL ACCOUNTS #{freshid_org_info[:total_size]}"
          page_count = freshid_org_info[:total_size] / ORGANISATION_LIST_ACCOUNTS_PAGE_SIZE
          total_pages = page_count.zero? ? 1 : page_count
          process_dangling_entrypoint_removal(freshid_org_info, entrypoint_id, exclude_accounts)
          paginated_org_accounts_entrypoint_removal(total_pages, organsation_detail.domain, entrypoint_id, exclude_accounts) if freshid_org_info[:has_more]
        end
      end
    end

    def paginated_org_accounts_entrypoint_removal(total_pages, org_domain, entrypoint_id, exclude_accounts)
      (2..total_pages).each do |page_number|
        org_accounts = Freshid::V2::Models::Account.organisation_accounts(page_number, ORGANISATION_LIST_ACCOUNTS_PAGE_SIZE, org_domain)
        break unless org_accounts[:accounts]

        process_dangling_entrypoint_removal(org_accounts, entrypoint_id, exclude_accounts)
      end
    end

    def process_dangling_entrypoint_removal(org_accounts, entrypoint_id, exclude_accounts)
      org_accounts[:accounts].each do |org_account|
        next if !(org_account[:product_id].eql? FRESHID_V2_PRODUCT_ID.to_s) || exclude_accounts.include?(org_account[:domain])

        domain_mapping = DomainMapping.find_by_domain(org_account[:domain])
        if domain_mapping
          Rails.logger.info "#{RAILS_LOGGER_PREFIX} Dangling Entrypoint Removal :: EXCLUDED ACCOUNTS #{exclude_accounts.count} "
          clear_entrypoints_from_account(domain_mapping.account_id, entrypoint_id)
        end
      end
    end

    def clear_entrypoints_from_account(account_id, entrypoint_id)
      account = nil
      Rails.logger.info "#{RAILS_LOGGER_PREFIX} Dangling Entrypoint Removal :: Clearing Entrypoint #{entrypoint_id} :: ACCOUNT #{account_id}"
      Sharding.admin_select_shard_of(account_id) do
        Sharding.run_on_slave do
          account = Account.find(account_id).make_current
          next unless account.freshid_org_v2_enabled? && account.freshid_sso_sync_enabled? && account.freshid_custom_policy_enabled_for_account?

          Sharding.run_on_master do
            process_entrypoint_deleted_event(entrypoint_id)
          end
        end
      end
    ensure
      Account.reset_current_account if account
    end

    # auth modules will contain password, google, sso
    def scrape_sso_changes(auth_modules)
      auth_modules.select { |auth_module| freshid_sso_event?(auth_module[:type]) }
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
      Rails.logger.error "#{RAILS_LOGGER_PREFIX} Error while updating entrypoint event #{e.inspect}, account_id: #{account_id}"
    ensure
      Freshid.account_class.reset_current_account
    end

    def filtered_sso_auth_modules(auth_modules = [])
      sso_enabled_auth_modules = auth_modules.select { |auth_module| auth_module[:enabled] == true }
      if sso_enabled_auth_modules.present?
        sso_enabled_auth_modules.first
      else
        auth_modules.first
      end
    end

    def process_freshid_custom_policy_events(entrypoint_param)
      entrypoint_hash = entrypoint_attrs(entrypoint_param)
      update_custom_policy(entrypoint_param[:entrypoint_enabled], entrypoint_param[:user_type].downcase.to_sym, entrypoint_hash)
      filtered_sso_auth_module = filtered_sso_auth_modules(scrape_sso_changes(entrypoint_param[:modules]))
      Rails.logger.info "#{RAILS_LOGGER_PREFIX} :: Processing Custom Policy SSO Auth Modules ::  #{filtered_sso_auth_module.inspect}"
      update_custom_sso_event(filtered_sso_auth_module[:enabled], entrypoint_param[:user_type], entrypoint_hash) if filtered_sso_auth_module.present?
    end

    def process_entrypoint_deleted_event(entrypoint_id)
      # Though the entrypoint event is deleted, the auth modules inside this event will have enabled as true/false because
      # freshid doesn't delete the authmodule(in our case sso module) associated with the entrypoint before sending the entrypoint
      # deleted event. So we need to handle it here.

      # Invalidating for contact
      invalidate_previous_configs(:agent, entrypoint_id)
      # Invaidating for agent
      invalidate_previous_configs(:contact, entrypoint_id)
    end

    def update_custom_policy(enable, entity, entrypoint_config = {})
      additional_settings = current_account.account_additional_settings
      if enable
        config = {}
        config[entity] = entrypoint_config.merge(logout_redirect_url: "https://#{current_account.full_domain}")
        invalidate_previous_configs(entity, entrypoint_config[:entrypoint_id])
        additional_settings.enable_freshid_custom_policy(config)
      else
        additional_settings.disable_freshid_custom_policy(entity)
      end
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

    def custom_policy_config_exists?(entity, entrypoint_id)
      config = current_account.freshid_custom_policy_enabled?(entity) || current_account.freshid_custom_sso_exists?(entity)
      config && config[:entrypoint_id] == entrypoint_id ? true : false
    end

    def invalidate_previous_configs(entity, entrypoint_id)
      additional_settings = current_account.account_additional_settings
      if entity == :agent && custom_policy_config_exists?(:contact, entrypoint_id)
        additional_settings.disable_freshid_custom_policy(:contact)
      elsif entity == :contact && custom_policy_config_exists?(:agent, entrypoint_id)
        additional_settings.disable_freshid_custom_policy(:agent)
      end
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
