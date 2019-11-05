module Widget
  module Search
    class SolutionsController < ApiSearch::SolutionsController
      include WidgetConcern

      before_filter :set_current_language

      def results
        @search_context = :portal_spotlight_solution
        @items = solution_category_meta_ids.blank? ? [] : esv2_query_results(esv2_portal_models)
      end

      private

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
            es_params[:article_company_id]  = User.current.company_ids if User.current && User.current.has_company?
            es_params[:size]  = 5
            es_params[:from]  = 1
            es_params[:sort_by]         = 'hits'
            es_params[:sort_direction]  = 'desc'
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
