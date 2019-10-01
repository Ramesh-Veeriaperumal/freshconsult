module ApiSearch
  class AutomationsController < Ember::Search::SpotlightController
    include Admin::AutomationConstants
    include AutomationRuleHelper

    def results
      @klasses = ['VaRule']
      @search_context = :search_automation
      @size = params[:limit]
      @page = params[:page]
      @query = params[:query]
      @sort_direction = 'desc'
      @search_sort = params[:sort_by]
      @items = esv2_query_results(esv2_automation_search_models)
      rule_type = @query.present? ? @query.split(':')[1].to_i : nil
      response.api_root_key = PRIVATE_API_ROOT_KEY_MAPPING[rule_type] if rule_type.present?
      response.api_meta = { count: @items.total_entries }
    end

    private

      def decorate_objects
        if @items.present?
          fetch_executed_ticket_counts
          @items.map! { |item| Admin::AutomationDecorator.new(item, nil).to_search_hash }
        end
      end

      def construct_es_params
        super.tap do |es_params|
          unless @search_sort.to_s == 'relevance'
            es_params[:sort_by]         = @search_sort
            es_params[:sort_direction]  = @sort_direction
          end
          es_params[:query] = @query if @query.present?
          es_params[:page] = @page if @page.present?
          es_params[:size] = @size if @size.present?
        end
      end
  end
end
