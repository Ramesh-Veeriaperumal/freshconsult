module Ember
  module Bootstrap
    class AgentsGroupsController < ApiApplicationController
      # Whenever we change the Structure (add/modify/remove keys), we will have to modify the below constant
      CURRENT_VERSION = 'private-v1'.freeze
      send_etags_along(AgentGroup::VERSION_MEMBER_KEY)

      def index
        response.api_root_key = :data
      end
    end
  end
end
