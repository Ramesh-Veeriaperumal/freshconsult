class Channel::Search::CustomersController < ::Ember::Search::CustomersController
  include ChannelAuthentication

  skip_before_filter :check_privilege, if: :skip_privilege_check?
  before_filter :channel_client_authentication

  PERMITTED_JWT_SOURCES = [:multiplexer].freeze

  private

    def skip_privilege_check?
      permitted_jwt_source? PERMITTED_JWT_SOURCES
    end
end
