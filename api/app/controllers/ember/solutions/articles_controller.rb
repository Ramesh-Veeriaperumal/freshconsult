module Ember
  module Solutions
    class ArticlesController < ApiSolutions::ArticlesController
      before_filter :filter_ids, only: [:index]

      MAX_IDS_COUNT = 10

      def index
        @user = User.find_by_id(params[:user_id]) if params[:user_id].present?
        super
      end

      def self.wrap_params
        ::SolutionConstants::ARTICLE_WRAP_PARAMS
      end

      private

        def load_objects
          @items = scoper.preload(conditional_preload_options).where(parent_id: @ids)
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
          @ids = params[:ids].to_s.split(',').map(&:to_i).reject(&:zero?).first(MAX_IDS_COUNT)
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

        # Since wrap params arguments are dynamic & needed for checking if the resource allows multipart, placing this at last.
        wrap_parameters(*wrap_params)
    end
  end
end
