class Vault::AccountWorker < BaseWorker
  sidekiq_options queue: :vault_account_update, retry: 0, failures: :exhausted

  SUCCESS = [204].freeze

  def perform(args)
    args.symbolize_keys!
    @account = Account.current
    case args[:action].to_s
    when PciConstants::ACCOUNT_UPDATE
      update_account
    when PciConstants::ACCOUNT_ROLLBACK
      delete_account
    else
      Rails.logger.info("invalid action  A- #{@account.id}. action = #{args[:action]}")
    end
  end

  private

    def update_account
      whitelisted_ip = @account.whitelisted_ip
      if @account.features_included?(:whitelisted_ips) && whitelisted_ip.try(:enabled)
        token = JWT::SecureServiceJWEFactory.new(PciConstants::ACTION[:write]).account_info_payload
        payload = whitelisted_ip.as_api_response(:vault_service)
        Vault::Client.new(PciConstants::ACCOUNT_INFO_URL, :put, token).update_account(payload.to_json)
      else
        @account.pci_compliance_field_enabled? && @account.revoke_feature(:pci_compliance_field)
        Rails.logger.info("whitelisted_ips feature is not enabled for A- #{@account.id}. hence feature is rollbacked")
      end
    end

    def delete_account
      token = JWT::SecureServiceJWEFactory.new(PciConstants::ACTION[:delete]).account_info_payload
      Vault::Client.new(PciConstants::ACCOUNT_INFO_URL, :delete, token).delete_account
      JWT::SecureFieldMethods.new.secure_fields_from_cache.map(&:destroy)
    end
end
