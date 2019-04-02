module Ember
  module Solutions
    class ArticlesController < ApiSolutions::ArticlesController
      include HelperConcern
      include BulkActionConcern
      include SolutionBulkActionConcern

      before_filter :filter_ids, only: [:index]
      before_filter :validate_bulk_update_article_params, :validate_language, only: [:bulk_update]

      decorate_views(decorate_object: [:article_content, :votes])

      MAX_IDS_COUNT = 10

      def index
        @user = User.find_by_id(params[:user_id]) if params[:user_id].present?
        super
      end

      def article_content
        @constants_klass = 'SolutionConstants'.freeze
        @validation_klass = 'SolutionArticleFilterValidation'.freeze
        return unless validate_query_params
        load_article
      end

      def bulk_update
        @succeeded_list = []
        @failed_list = []
        @article_meta = meta_scoper.where(id: cname_params[:ids]).preload(:solution_folder_meta, primary_article: [:solution_folder_meta, :article_body])
        @article_meta.each do |article_meta|
          if update_article_properties(article_meta)
            @succeeded_list << article_meta.id
          else
            @failed_list << (article_meta.errors.any? ? article_meta : article_meta.safe_send(language_scoper))
          end
        end
        render_bulk_action_response(@succeeded_list, @failed_list)
      end

      def reset_ratings
        validate_request_params
        @delegator_klass = 'ApiSolutions::ArticleDelegator'
        return unless validate_delegator(@item)

        @item.reset_ratings ? (head 204) : render_errors(@item.errors)
      end

      def self.wrap_params
        ::SolutionConstants::ARTICLE_WRAP_PARAMS
      end

      private

        def constants_class
          'SolutionsConstants'.freeze
        end

        def load_article
          language_id = params[:language_id] || Language.for_current_account.id
          @item = scoper.where(parent_id: params[:id], language_id: language_id).first
          log_and_render_404 unless @item
        end

        def load_objects
          language_id = params[:language_id] || Language.for_current_account.id
          @items = scoper.preload(conditional_preload_options).where(parent_id: @ids, language_id: language_id)
          # Instead of using validation to give 4xx response for bad ids,
          # we are going to tolerate and send response for the good ones alone.
          # Because the primary use case for this is Recently used Solution articles
          log_and_render_404 if @items.blank?
        end

        def conditional_preload_options
          preload_options = ::SolutionConstants::INDEX_PRELOAD_OPTIONS
          return preload_options unless @user
          preload_options | [{ solution_article_meta: [solution_folder_meta: :customer_folders] }]
        end

        def filter_ids
          params[:ids] = params[:ids].try(:to_s).try(:split, ',') if params[:ids] && params[:ids].is_a?(String)
          @ids = (params[:ids] || []).map(&:to_i).reject(&:zero?).first(MAX_IDS_COUNT)
          log_and_render_404 if @ids.blank?
        end

        def validate_filter_params
          params.permit(*SolutionConstants::RECENT_ARTICLES_FIELDS, *ApiConstants::DEFAULT_INDEX_FIELDS)
          @article_filter = SolutionArticleFilterValidation.new(params)
          render_errors(@article_filter.errors, @article_filter.error_options) unless @article_filter.valid?
        end

        def decorator_options
          options = {}
          options[:user] = @user if @user
          [::Solutions::ArticleDecorator, options]
        end

        def validate_request_params
          params[cname].permit([])
        end

        # Since wrap params arguments are dynamic & needed for checking if the resource allows multipart, placing this at last.
        wrap_parameters(*wrap_params)
    end
  end
end
