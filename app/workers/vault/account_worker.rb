class Vault::AccountWorker < BaseWorker
  sidekiq_options queue: :vault_account_update, retry: 0, failures: :exhausted

  SUCCESS = [204].freeze

  def perform(args)
    args.symbolize_keys!
    @account = Account.current
    case args[:action].to_s
    when PciConstants::ACCOUNT_UPDATE
      update_account(args)
    when PciConstants::ACCOUNT_ROLLBACK
      delete_account
    else
      Rails.logger.info("invalid action  A- #{@account.id}. action = #{args[:action]}")
    end
  end

  private

    def update_account(args)
      whitelisted_ip = @account.whitelisted_ip
      if @account.features_included?(:whitelisted_ips) && whitelisted_ip.try(:enabled)
        token = JWT::SecureServiceJWEFactory.new(PciConstants::ACTION[:write]).account_info_payload
        payload = whitelisted_ip.as_api_response(:vault_service)
        Vault::Client.new(PciConstants::ACCOUNT_INFO_URL, :put, token).update_account(payload.to_json)
        if args[:enable_pci_compliance]
          @account.add_feature(:single_session_per_user)
          @account.launch(:idle_session_timeout)
        end
      else
        @account.secure_fields_enabled? && @account.disable_setting(:secure_fields)
        Rails.logger.info("whitelisted_ips feature is not enabled for A- #{@account.id}. hence feature is rollbacked")
      end
    end

    def delete_account
      Tickets::VaultDataCleanupWorker.new.perform(field_names: PciConstants::ALL_FIELDS)
      token = JWT::SecureServiceJWEFactory.new(PciConstants::ACTION[:delete]).account_info_payload
      Vault::Client.new(PciConstants::ACCOUNT_INFO_URL, :delete, token).delete_account
      JWT::SecureFieldMethods.new.secure_fields_from_cache.map(&:destroy)
    end
end
