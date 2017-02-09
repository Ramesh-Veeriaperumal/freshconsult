module Ember
  module Search
    class TopicsController < SpotlightController

      def results
        @klasses = ['Topic']
        @category_id = params[:category_id].to_i if params[:category_id].present?
        @sort_direction = 'desc'

        if params[:context] == 'spotlight'
          @search_context = :agent_spotlight_topic
          @search_sort = params[:search_sort] if params[:search_sort].present?
        elsif params[:context] == 'merge'
          @search_context = :merge_topic_search
          @search_sort    = 'created_at'
          @visibility	= params[:visibility].to_i if params[:visibility].present?
        end

        @items = esv2_query_results(esv2_agent_models)
        response.api_meta = { count: @items.count }
      end

      private

        def decorator_options
          [Discussions::TopicDecorator, {}]
        end

        def construct_es_params
          super.tap do |es_params|
            es_params[:topic_category_id] = @category_id
            es_params[:topic_visibility]  =	@visibility if @search_context == :merge_topic_search

            unless (@search_sort.to_s == 'relevance') || @suggest
              es_params[:sort_by]         = @search_sort
              es_params[:sort_direction]  = @sort_direction
            end

            es_params[:size]  = @size
            es_params[:from]  = @offset
          end
        end
    end
  end
end
