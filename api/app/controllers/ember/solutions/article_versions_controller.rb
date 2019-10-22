module Ember
  module Solutions
    class ArticleVersionsController < ApiApplicationController
      include HelperConcern
      include SolutionConcern

      SLAVE_ACTIONS = %w[index].freeze

      decorate_views(decorate_object: [:show], decorate_objects: [:index])

      # load_obejct or before_load_object will not be called for index actions
      before_filter :load_article, only: [:index]

      def index
        super
        response.api_meta = { count: @items_count, next_page: @more_items }
      end

      private

        def constants_class
          'Ember::Solutions::ArticleVersionConstants'.freeze
        end

        def article_scoper
          current_account.solution_articles.where(parent_id: params[:article_id], language_id: @lang_id)
        end

        def load_article
          return unless validate_language
          @article = article_scoper.first
          log_and_render_404 unless @article
        end

        # we need to load article before loading article
        alias before_load_object load_article

        # don't add latest scope here. we don't need ordering for load_object. we need only for load_objects
        def scoper
          @article.solution_article_versions
        end

        def load_object
          @item = scoper.where(version_no: params[:id]).first
          log_and_render_404 unless @item
        end

        def load_objects
          super(scoper.latest)
        end

        def feature_name
          :article_versioning
        end

        def validate_filter_params
          super(Ember::Solutions::ArticleVersionConstants::INDEX_FIELDS)
        end
    end
  end
end
