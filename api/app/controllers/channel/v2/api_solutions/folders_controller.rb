module Channel::V2::ApiSolutions
  class FoldersController < ::ApiSolutions::FoldersController

    include ChannelAuthentication
    
    skip_before_filter :check_privilege, :verify_authenticity_token, only: [:index, :show, :category_folders]
    before_filter :channel_client_authentication, only: [:index, :show, :category_folders]

    def self.decorator_name
      ::Solutions::FolderDecorator
    end
  end
end
