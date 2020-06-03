class Freshid::Fdadmin::FreshidV1ToV2Migration < ActiveRecord::Migration
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Freshid::Fdadmin::MigrationHelper
  include Freshid::V2::Migration::MigratorExtensions

  attr_accessor :product_account_mapping, :chain_migration

  def initialize(doer_email, chain_migration = true)
    @freshchat_path = FreshIDV2Config['v2_migration_freshchat_path']
    @freshchat_host = FreshIDV2Config['v2_migration_freshchat_host']
    @freshchat_int_name = FreshIDV2Config['v2_migration_freshchat_int_name']
    @freshchat_token = FreshIDV2Config['v2_migration_freshchat_token']
    @product_account_mapping = FreshIDV2Config['v2_migration_product_mapping'].deep_symbolize_keys

    @freshconnect_product_name = :freshconnect
    @freshcaller_product_name = :freshcaller
    @freshchat_product_name = :freshchat
    @freshsales_product_name = :freshsales

    @migrated_list = []
    @doer_email = doer_email
    @chain_migration = chain_migration
  end

  def migrate_account(account_id, org_domain = nil)
    Rails.logger.info "FRESHID V2 MIGRATION :: Started for a=#{account_id} and org_domain=#{org_domain}"
    accounts = []
    success = false
    @v2_organisation_details = []
    fetch_account(account_id) do |account|
      begin
        return unless can_migrate(account)

        accounts.push('domain' => account.full_domain,
                      'external_id' => account.id.to_s,
                      'product_id' => FRESHID_V2_PRODUCT_ID.to_s) # TODO: we are pushing this and other mapped accounts too.

        if @chain_migration
          linked_accounts, stop_migration = linked_accounts(account)
          if stop_migration
            Rails.logger.info "FRESHID V2 MIGRATION :: migrate_account :: a=#{account_id} stopping migration due to multiple accounts in organisation"
            return
          end
          accounts.push(*linked_accounts)
        end
        sandbox_account = fetch_sandbox_account(account)
        accounts.push(*sandbox_account)
        org_domain = @v2_organisation_details.first if @v2_organisation_details.count == 1
        Rails.logger.info("FRESHID V2 MIGRATION :: migrate_account :: a=#{account_id} multiple linked accounts in v2 count=#{@v2_organisation_details.count}, #{@v2_organisation_details.inspect}") if @v2_organisation_details.count > 1

        body = { admin_emails: account_admin_emails(account), accounts: accounts }
        body[:organisation_domain] = org_domain if org_domain.present?
        password_policy_payload = build_policy_payload(account)
        body[:password_policy] = password_policy_payload if password_policy_payload.present?

        response = migrate(body.to_json)
        Rails.logger.info "FRESHID V2 MIGRATION :: migrate_account :: a=#{account.id}, d=#{account.full_domain}, http_status_code=#{response.http_status_code}, response=#{response.body}"
        success = !response.is_error
      rescue StandardError => e
        Rails.logger.error "FRESHID V2 MIGRATION ERROR: a=#{account_id}, message=#{e.message}"
      ensure
        send_email(account_id, success)
        Rails.logger.info "FRESHID V2 MIGRATION :: Finished for a=#{account_id} and org_domain=#{org_domain}"
        return success
      end
    end
  end

  private

  def send_email(account_id, success)
    message = success ? "Freshid Org V2 Migration for A = #{account_id} Successfully Done"
                      : 'Freshid Org V2 Migration executed with some error, Please contact Freshdesk dev team'
    subject = "#{FRESHID_V2_EMAIL_SUBJECT} A = #{account_id}"
    Emailer.export_logs([], subject, message, @doer_email)
  end

  def fetch_freshchat_accounts(account, linked_accounts)
    account.freshchat_account
  end

  def get_client_cred_with_domain_token_from_cache(org_domain = nil)
    $redis_others.perform_redis_op('get', format(FRESHID_V2_ORG_CLIENT_CREDS_TOKEN_KEY, organisation_domain: org_domain))
  end

  ## return array of account admin emails to be mapped to org_Admin
  def account_admin_emails(account)
    account.account_managers.map(&:email)
  end

  def can_migrate(account)
    freshid_v1_sucessfully_migrated = agent_mapped_correctly?(account)
    Rails.logger.info "FRESHID V2 MIGRATION :: can_migrate :: a=#{account.id}, freshid_enabled=#{account.freshid_enabled?}, freshid_sso_enabled=#{account.freshid_sso_enabled?}, Org_v2_enabled=#{account.freshid_org_v2_enabled?}, freshid_v1_sucessfully_migrated=#{freshid_v1_sucessfully_migrated}"
    account.freshid_enabled? && !account.freshid_sso_enabled? && !account.freshid_org_v2_enabled? && freshid_v1_sucessfully_migrated
  end

  def can_migrate_linked_account(account_info)
    return if account_info.blank?
    domain = account_info[:domain]
    freshid_v2_organisation_details = find_account_mapped_v2(domain)
    if freshid_v2_organisation_details.present?
      Rails.logger.info "FRESHID V2 MIGRATION :: can_migrate_linked_account :: account already migrated to V2 acc_domain:#{domain}, org_domain:#{freshid_v2_organisation_details[:domain]}"
      @v2_organisation_details << freshid_v2_organisation_details[:domain]
      return false
    end
    true
  end

  def linked_accounts(account)
    accounts_info = []
    linked_accounts, ignore_count = fetch_accounts_in_org_v1(account.full_domain)
    return nil, true if ignore_count > 0 # TODO: why
    linked_accounts = filter_linked_accounts(linked_accounts)
    accounts_info.push(*linked_accounts)

    freshconnect_account = fetch_freshconnect_accounts(account, linked_accounts) # TODO: why empty
    freshcaller_account = fetch_freshcaller_accounts(account, linked_accounts)
    freshchat_account_from_db = fetch_freshchat_accounts(account, linked_accounts)

    freshchat_request_params = { app_domain: account.full_domain }
    if freshchat_account_from_db.present?
      freshchat_request_params = freshchat_request_params.merge(appId: freshchat_account_from_db.app_id)
      freshchat_response = freshchat_migration_valid?(freshchat_request_params)
      if response_error?(freshchat_response)
        Rails.logger.info "FRESHID V2 MIGRATION :: linked_accounts :: a=#{account.id} Skipping migration for due freshchat_account integration api call failed"
        return nil, true
      else
        freshchat_account = freshchat_response.body.present? ? [{
          domain: get_freshchat_preferred_domain(freshchat_response.body[:domain].to_s),
          external_id: freshchat_response.body[:appId].to_s,
          product_id: @product_account_mapping[:freshchat].to_s
        }] : []
        migrate_freshchat = true
      end
    else
      Rails.logger.info "FRESHID V2 MIGRATION :: linked_accounts :: a=#{account.id} Freshchat account not present in FreshDesk"
    end

    freshconnect_account = filter_linked_accounts(freshconnect_account)
    freshcaller_account = filter_linked_accounts(freshcaller_account)
    freshchat_account = filter_linked_accounts(freshchat_account)

    accounts_info.push(*freshconnect_account) # TODO: we have already pushed these accounts by getting it from v1
    accounts_info.push(*freshcaller_account)
    accounts_info.push(*freshchat_account) if migrate_freshchat
    [accounts_info, false]
  end

  def fetch_accounts_in_org_v1(domain)
    response = Freshid::ApiCalls.other_mapped_accounts(domain)
    accounts = []
    ignore_count = 0
    if response.present? && response.include?(:response)
      Rails.logger.info "FRESHID V2 MIGRATION :: fetch_accounts_in_org_v1 :: acc_domain:#{domain}, accounts in organisation V1 #{response.inspect}"
      response[:response].each do |account|
        account.deep_symbolize_keys
        product_name = account[:product][:name].to_sym
        product_info_present = @product_account_mapping.include?(product_name)
        if product_info_present && account[:domain] != domain # TODO: will freshconnect, freshchat have different domains than freshdesk.
          accounts.push(domain: account[:domain],
                        external_id: '',
                        product_id: @product_account_mapping[product_name].to_s)
        elsif !product_info_present && account[:domain].include?('.freshdesk.com') && account[:domain] != domain
          external_acc_id = DomainMapping.find_by_domain(account[:domain]).account_id.to_s
          if external_acc_id.present?
            accounts.push(domain: account[:domain],
                          external_id: external_acc_id,
                          product_id: FRESHID_V2_PRODUCT_ID.to_s)
          end
        else
          ignore_count += 1 if !product_info_present && account[:domain] != domain # TODO: should it be OR condition
          Rails.logger.info "FRESHID V2 MIGRATION :: fetch_accounts_in_org_v1 :: account migration skipped acc_domain:#{account[:domain]}, product_account_mapping present:#{product_info_present}, parent_domain:#{domain}"
        end
      end
    end
    [accounts, ignore_count]
  end

  def find_account_mapped_v2(domain)
    Freshid::V2::Models::Organisation.find_account_by_domain(domain)
  end

  def fetch_account(account_id)
    Sharding.admin_select_shard_of(account_id) do
      Sharding.run_on_slave do
        account = Freshid.account_class.find(account_id).make_current
        yield(account)
      end
    end
  rescue StandardError => e
    Rails.logger.error "FRESHID V2 MIGRATION ERROR :: fetch_account :: a=#{account_id}, message=#{e.message}"
  ensure
    Freshid.account_class.reset_current_account
  end

  def linked_account_present?(linked_accounts, product_id, domain)
    linked_accounts.any? { |acc| (acc[:product_id] == product_id && acc[:domain] == domain) }
  end

  def build_policy_payload(account)
    policies = account.agent_password_policy.try(:policies)
    config = account.agent_password_policy.try(:configs)
    hash = {}
    return hash if policies.nil?
    hash['size'] = config['minimum_characters'].to_i if policies.include?(:minimum_characters)
    hash['allow_personal_info'] = !policies.include?(:cannot_contain_user_name)
    hash['history_count'] = config['cannot_be_same_as_past_passwords'].to_i if policies.include?(:cannot_be_same_as_past_passwords)
    hash['special_characters_count'] = 1 if policies.include?(:have_special_character)
    hash['numeric_characters_count'] = 1 if policies.include?(:atleast_an_alphabet_and_number)
    hash['mixed_case_characters_count'] = 1 if policies.include?(:have_mixed_case)
    password_expiry = config['password_expiry'].to_i < 180 ? config['password_expiry'].to_i : 180
    hash['password_expiry_days'] = password_expiry if policies.include?(:password_expiry)
    hash
  rescue StandardError => e
    Rails.logger.info "FRESHID V2 MIGRATION ::  build_policy_payload :: a=#{account.id}, Exception: #{e.inspect}"
  end

  def filter_linked_accounts(accounts)
    valid_linked_accounts = []
    accounts.each do |account_info|
      valid_linked_accounts << account_info if can_migrate_linked_account(account_info)
    end
    valid_linked_accounts
  end

  ## start HTTP helpers ##
  def migrate(body)
    url = Freshid::V2::UrlGenerator.migration_url
    response = send_request_with_client_cred_auth(:patch, url, body)
    response
  end

  def generate_client_credential_token
    credentials = Freshid::V2::Auth.refresh_client_access_token.try(:credentials)
    credentials.access_token
  end

  def send_request_with_client_cred_auth(req_type, url, body)
    response = send_request(req_type, url, "Bearer #{@token}", body)
    if response.nil? || (response.is_error && (response.http_status_code == 401 || response.http_status_code == 403))
      @token = generate_client_credential_token
      response = send_request(req_type, url, "Bearer #{@token}", body)
    end
    response
  end

  def send_request(req_type, url, auth, body, headers = nil, suppress_failure = false)
    request = Freshid::HttpServiceMethods.new(req_type, url, auth, body, headers, suppress_failure, timeout: 180)
    request.send_request
    request.response
  end

  def freshchat_migration_valid?(query_params = {})
    query_params[:token] = @freshchat_token
    query_params[:product_name] = @freshchat_int_name
    uri = build_custom_url(@freshchat_host, @freshchat_path, query_params)
    response = send_request(:get, uri, nil, nil)
    Rails.logger.info "FRESHID V2 MIGRATION :: freshchat_migration_valid :: uri=#{uri}, Freshchat response #{response.inspect}"
    response
  end

  def build_custom_url(host, path, query_params = {})
    URI::HTTPS.build(host: host, path: path, query: URI.encode_www_form(query_params)).to_s
  end

  def response_error?(response)
    response.nil? || response.http_status_code != 200
  end
  ## end HTTP helpers ##
end
