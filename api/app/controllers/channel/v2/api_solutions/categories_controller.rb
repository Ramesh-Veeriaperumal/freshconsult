module Channel::V2::ApiSolutions
  class CategoriesController < ::ApiSolutions::CategoriesController

    include ChannelAuthentication
    
    skip_before_filter :check_privilege, :verify_authenticity_token, only: [:index, :show]
    before_filter :channel_client_authentication, only: [:index, :show]

    def self.decorator_name
      ::Solutions::CategoryDecorator
    end
  end
end
