module Channel::V2::ApiSolutions
  class ArticlesController < ::ApiSolutions::ArticlesController
    include ChannelAuthentication

    skip_before_filter :check_privilege, :verify_authenticity_token, only: [:folder_articles, :search, :show, :index]
    before_filter :channel_client_authentication, only: [:folder_articles, :search, :show, :index]
    before_filter :validate_search_query_parameters, only: [:search]
    before_filter :validate_chat_query_parameters, only: [:folder_articles]

    def self.decorator_name
      ::Solutions::ArticleDecorator
    end

    def show
      @enrich_response = true
      super
    end
  end
end
