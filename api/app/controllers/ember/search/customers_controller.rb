module Ember
	module Search
		class CustomersController < SpotlightController
			decorate_views(decorate_objects: [:results])

			COLLECTION_RESPONSE_FOR = %w(results).freeze

			def results
				if params[:context] == 'spotlight'
						@klasses        = ['User', 'company']
					  @search_context = :agent_spotlight_customer
					  @items = esv2_query_results(esv2_agent_models)
				elsif params[:context] == 'merge'
						
						# Only Contact Merge

				    @klasses        = ['User']
				    @source_user_id	= params[:source_user_id]
				    @search_context = :contact_merge
				    @items = esv2_query_results(esv2_contact_merge_models)
				end

				response.api_meta = { count: @items.count }
			end

	    private

	      def decorate_objects
	      	company_name_mapping = Company.new.custom_field.each_with_object({}) { |(name, value), hash| hash[name] = CustomFieldDecorator.display_name(name) }
	      	contact_name_mapping = User.new.custom_field.each_with_object({}) { |(name, value), hash| hash[name] = CustomFieldDecorator.display_name(name) }
    			@items.map! { |item| item.is_a?(User) ? ContactDecorator.new(item, {name_mapping: contact_name_mapping}) : CompanyDecorator.new(item,{name_mapping: company_name_mapping}) } 
  			end

		    def construct_es_params
		      super.tap do |es_params|

		        if @search_context == :contact_merge
		        	es_params[:source_id] = @source_user_id
		        	es_params.merge!(ES_V2_BOOST_VALUES[:contact_merge])
		        end

		        unless (@search_sort.to_s == 'relevance') or @suggest
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