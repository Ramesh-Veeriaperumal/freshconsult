module Ember
	module Search
		class SolutionsController < SpotlightController
			decorate_views(decorate_objects: [:results])

			COLLECTION_RESPONSE_FOR = %w(results).freeze

			def results
				if params[:context] == 'spotlight'
					@search_context = :agent_spotlight_solution
			    @klasses        = ['Solution::Article']
			    @category_id 		= params[:category_id].to_i if params[:category_id].present?
			    @folder_id 			= params[:folder_id].to_i if params[:folder_id].present?
			    @sort_direction = 'desc'
			    @search_sort		= params[:search_sort] if params[:search_sort].present?
					@language_id 		= params[:language] if params[:language].present? && current_account.es_multilang_soln?
	# allow_auto_suggest_solutions
			    @items 					= esv2_query_results(esv2_agent_models)
				elsif params[:context] == 'insert_solutions'
					@klasses            = ['Solution::Article']
      		@search_context     = :agent_insert_solution
      		@category_id 		= params[:category_id].to_i if params[:category_id].present?
			    @folder_id 			= params[:folder_id].to_i if params[:folder_id].present?
					@language_id 		= params[:language] if params[:language].present? && current_account.es_multilang_soln?
					@sort_direction = 'desc'
					@search_sort		= params[:search_sort] if params[:search_sort].present?
					@items = esv2_query_results(esv2_agent_models)
				end

				# @items = esv2_query_results(esv2_agent_models)
				response.api_meta = { count: @items.count }
			end

	    private

	    	def decorator_options
	    		[Solutions::ArticleDecorator,{}]
			  end

		    def construct_es_params
		      super.tap do |es_params|

          	es_params[:article_category_id] = @category_id 
          	es_params[:article_folder_id] = @folder_id

            es_params[:language_id] = @language_id || Language.for_current_account.id


		      	unless (@search_sort.to_s == 'relevance')
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