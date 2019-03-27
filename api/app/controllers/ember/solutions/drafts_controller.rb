module Ember
  module Solutions
    class DraftsController < ApiApplicationController
      include HelperConcern
      include SolutionConcern

      before_filter :validate_language, only: [:index]

      def index
        drafts = current_account.solution_drafts.my_drafts(params[:portal_id], @lang_id).preload(preload_options)
        @items = drafts.first(ApiSolutions::DraftConstants::RECENT_DRAFTS_LIMIT)
        response.api_meta = { count: drafts.count }
      end

      private

        def constants_class
          'ApiSolutions::DraftConstants'.freeze
        end

        def validate_filter_params
          return unless validate_query_params
          return unless validate_delegator(nil, portal_id: params[:portal_id])
        end

        def preload_options
          [{ article: { solution_article_meta: :solution_folder_meta } }, :attachments, :draft_body]
        end
    end
  end
end
