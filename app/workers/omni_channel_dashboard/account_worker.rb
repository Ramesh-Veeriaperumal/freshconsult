# frozen_string_literal: true

class OmniChannelDashboard::AccountWorker < BaseWorker
  sidekiq_options queue: :touchstone_account_update, retry: 0, failures: :exhausted

  include OmniChannelDashboard::Constants

  def perform(args)
    args.symbolize_keys!
    @account = Account.current
    case args[:action].to_s
    when 'update'
      get_token_and_execute(ACCOUNT_UPDATE_API_PATH + @account.try(:id).try(:to_s), :put)
    when 'create'
      get_token_and_execute(ACCOUNT_CREATE_API_PATH, :post)
    else
      Rails.logger.info("invalid action  A- #{@account.id}. action = #{args[:action]}")
    end
  end

  private

    def get_token_and_execute(endpoint, method)
      if @account.omni_bundle_2020_enabled? && @account.freshchat_account.present? && @account.freshcaller_account.present?
        token = OmniChannelDashboard::JwtAuthentication.new.jwt_token
        OmniChannelDashboard::Client.new(endpoint, method, token).account_create_or_update(payload_hash.to_json)
      else
        Rails.logger.info("Omni bundle feature is not enabled for A - #{@account.id}. Hence could not enable Omni Channel Dashboard")
      end
    end

    def payload_hash
      request_payload = @account.as_api_response(:touchstone)
      request_payload.merge!(@account.freshchat_account.as_api_response(:touchstone)) if @account.freshchat_account.present?
      request_payload.merge!(@account.freshcaller_account.as_api_response(:touchstone)) if @account.freshcaller_account.present?
      request_payload
    end
end
