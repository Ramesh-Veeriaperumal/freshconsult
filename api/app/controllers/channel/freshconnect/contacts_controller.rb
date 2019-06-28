module Channel::Freshconnect
  class ContactsController < ::ApiContactsController
    include ChannelAuthentication

    skip_before_filter :check_privilege
    before_filter :channel_client_authentication

    SLAVE_ACTIONS = %w[show].freeze

    def self.decorator_name
      ::ContactDecorator
    end

    private

    def scoper
      # Freshconnect would need contact details of agents alone
      current_account.all_technicians
    end
  end
end
