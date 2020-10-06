# frozen_string_literal: true

class OmniChannelUpgrade::LinkAccount < BaseWorker
  sidekiq_options queue: :link_omni_account, retry: 5, backtrace: true, failures: :exhausted

  include Freshchat::JwtAuthentication
  include Freshchat::Util
  include Freshcaller::Util
  include OmniChannel::Util
  include OmniChannel::Constants

  def perform(args)
    args.symbolize_keys!
    account = Account.current
    product_name = args[:product_name]
    link_params = args[:params]
    performer_id = args[:performer_id]
    link_accounts(account, product_name, link_params)
  rescue StandardError => e
    Rails.logger.error "Error while updating access token for product #{product_name} Account ID: #{account.id} Exception: #{e.message} :: #{e.backtrace[0..20].inspect}"
    NewRelic::Agent.notice_error(e, account_id: Account.current.id, args: args)
    raise e
  end

  private

    def link_accounts(account, product_name, link_params)
      if product_name == FRESHCALLER
        freshcaller_account_domain = account.freshcaller_account.domain
        response = send_access_token_to_caller(freshcaller_account_domain, link_params)
        raise StandardError, "#{product_name} response error" unless valid_freshcaller_response?(response)
      elsif product_name == FRESHCHAT
        freshchat_account = account.freshchat_account
        access_token = link_params[:access_token]
        response = update_access_token(account.domain, access_token, freshchat_account, freshchat_jwt_token)
        raise StandardError, "#{product_name} response error" unless valid_freshchat_response?(response)
      end
    end

    def valid_freshcaller_response?(response)
      parsed_response = response.parsed_response
      response.code == 200 && parsed_response['error'].nil?
    end

    def valid_freshchat_response?(response)
      response.code == 200
    end
end
