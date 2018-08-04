module Channel
  class AttachmentsController < ::Ember::AttachmentsController
    include ChannelAuthentication

    skip_before_filter :check_privilege
    before_filter :channel_client_authentication

    def create
      super
    end
  end
end
