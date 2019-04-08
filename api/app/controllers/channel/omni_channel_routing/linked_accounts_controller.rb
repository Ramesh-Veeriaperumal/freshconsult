module Channel::OmniChannelRouting
  class LinkedAccountsController < ApiApplicationController
    include ChannelAuthentication
    include ::OmniChannelRouting::Util

    skip_before_filter :check_privilege, :load_object, :verify_authenticity_token
    before_filter :log_request_header, :channel_client_authentication

    def index
      linked_accounts = []
      linked_accounts << { id: current_account.id.to_s, product: 'freshdesk', domain: current_account.full_domain }
      if current_account.freshchat_account
        freshchat_account = current_account.freshchat_account
        linked_accounts << { id: freshchat_account.app_id, product: 'freshchat', domain: URI::parse(Freshchat::Account::CONFIG[:agentWidgetHostUrl]).host, enabled: freshchat_account.enabled } if freshchat_account.enabled
      end
      if current_account.freshcaller_account
        freshcaller_account = current_account.freshcaller_account
        linked_accounts << { id: freshcaller_account.freshcaller_account_id.to_s, product: 'freshcaller', domain: freshcaller_account.domain }
      end
      @response = { accounts: linked_accounts }
    end

    def update
      success = false
      account_additional_settings = current_account.account_additional_settings
      account_additional_settings.additional_settings ||= {}
      account_additional_settings.additional_settings[:ocr_account_id] = params[:ocr_account_id]
      success = account_additional_settings.save
      return head 204 if success
      render_errors(account_additional_settings.errors) if account_additional_settings.errors.present?
    end
  end
end
