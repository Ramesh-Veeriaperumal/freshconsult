module Channel::V2::ApiSolutions
  class ArticlesController < ::ApiSolutions::ArticlesController
    include ChannelAuthentication

    skip_before_filter :check_privilege, :verify_authenticity_token, only: [:folder_articles, :show, :index]
    before_filter :channel_client_authentication, only: [:folder_articles, :show, :index]
    before_filter :validate_chat_query_parameters, only: [:folder_articles]
    before_filter :sanitize_chat_params, only: [:folder_articles], if: :chat_params_present?
    before_filter :reconstruct_params, only: [:folder_articles], if: :tags_or_platforms_present?
    before_filter :validate_chat_params, only: [:folder_articles]
    before_filter :portal_delegator_validation, only: [:folder_articles]

    def self.decorator_name
      ::Solutions::ArticleDecorator
    end

    def show
      @enrich_response = true
      super
    end

    private

      def portal_delegator_validation
        if params[:portal_id].present?
          @delegator_klass = 'ApiSolutions::ArticleDelegator'
          return unless validate_delegator(nil, portal_id: params[:portal_id])
        end
      end
  end
end
