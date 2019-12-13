module Widget
  module Search
    class SolutionsController < ApiSearch::SolutionsController
      include HelperConcern
      include WidgetConcern
      include Widget::Search::SolutionConstants

      before_filter :set_current_language
      before_filter :validate_query_params, only: [:results]

      def results
        @search_context = :portal_spotlight_solution
        @items = solution_category_meta_ids.blank? ? [] : esv2_query_results(esv2_portal_models)
      end

      private
        def constants_class
          Widget::Search::SolutionConstants
        end

        def decorator_options
          [Widget::Solutions::ArticleDecorator]
        end

        def searchable_klasses
          @klasses = ['Solution::Article']
        end

        def construct_es_params
          super.tap do |es_params|
            es_params[:language_id] = Language.current.id
            es_params[:article_status] = SearchUtil::DEFAULT_SEARCH_VALUE.to_i
            es_params[:article_visibility] = user_visibility
            es_params[:article_category_id] = solution_category_meta_ids
            es_params[:article_company_id]  = current_user.company_ids if current_user && current_user.has_company?
            es_params[:page] = params.fetch(:page, DEFAULT_PAGE)
            es_params[:size] = params.fetch(:per_page, DEFAULT_PER_PAGE)
          end
        end

        def solution_category_meta_ids
          @solution_category_meta_ids ||= begin
            @help_widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
          end
        end
    end
  end
end
