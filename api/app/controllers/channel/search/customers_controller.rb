class Channel::Search::CustomersController < ::Ember::Search::CustomersController
  include ChannelAuthentication

  skip_before_filter :check_privilege, if: :skip_privilege_check?
  before_filter :channel_client_authentication

  private

    def skip_privilege_check?
      channel_source?(:multiplexer)
    end
end
