module Channel::V2::ApiSolutions
  class ArticlesController < ::ApiSolutions::ArticlesController
    include ChannelAuthentication

    skip_before_filter :check_privilege, :verify_authenticity_token, only: [:folder_articles, :show, :index]
    before_filter :channel_client_authentication, only: [:folder_articles, :show, :index]

    def self.decorator_name
      ::Solutions::ArticleDecorator
    end

    def show
      @enrich_response = true
      super
    end
  end
end
