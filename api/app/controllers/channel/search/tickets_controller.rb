module Channel
  module Search
    class TicketsController < ::Ember::Search::TicketsController
      include ChannelAuthentication

      def results
        @skip_user_privilege = true
        super
      end

      skip_before_filter :check_privilege, if: :skip_privilege_check?
      before_filter :channel_client_authentication

      def skip_privilege_check?
        channel_source?(:sherlock)
      end
    end
  end
end
