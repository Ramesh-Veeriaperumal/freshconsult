module Channel::OmniChannelRouting
  class LinkedAccountsController < ApiApplicationController
    include ChannelAuthentication
    skip_before_filter :check_privilege
    before_filter :channel_client_authentication

    def index
      linked_accounts = []
      linked_accounts << { id: current_account.id, product: 'freshdesk', domain: current_account.full_domain }
      if current_account.freshchat_account
        freshchat_account = current_account.freshchat_account
        linked_accounts << { id: freshchat_account.id, product: 'freshchat', domain: 'freshchat.com', enabled: freshchat_account.enabled }
      end
      if current_account.freshcaller_account
        freshcaller_account = current_account.freshcaller_account
        linked_accounts << { id: freshcaller_account.freshcaller_account_id, product: 'freshcaller', domain: freshcaller_account.domain }
      end
      @item = { accounts: linked_accounts }
    end
  end
end
