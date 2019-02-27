module Widget
  module Search
    class SolutionsController < ApiSearch::SolutionsController
      include WidgetConcern

      skip_before_filter :check_privilege

      before_filter :check_feature
      before_filter :check_open_solutions
      before_filter :validate_widget
      before_filter :set_widget_portal_as_current
      before_filter :set_current_language

      def results
        @search_context = :portal_spotlight_solution
        @items = esv2_query_results(esv2_portal_models)
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
            es_params[:article_visibility] = [Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]]
            es_params[:article_category_id] = @current_portal.portal_solution_categories.map(&:solution_category_meta_id)
            es_params[:size]  = 5
            es_params[:from]  = 1
            es_params[:sort_by]         = 'hits'
            es_params[:sort_direction]  = 'desc'
          end
        end
    end
  end
end
