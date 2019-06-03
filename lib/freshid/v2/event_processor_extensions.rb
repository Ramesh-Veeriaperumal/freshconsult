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
end
