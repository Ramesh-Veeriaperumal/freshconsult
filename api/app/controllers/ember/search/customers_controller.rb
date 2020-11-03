module Ember
  module Search
    class CustomersController < SpotlightController
      def results
        case params[:context]
        when 'merge'
          # Only Contact Merge
          @klasses = ['User']
          @source_user_id	= params[:source_user_id]
          @search_context = :contact_merge
          @items = esv2_query_results(esv2_contact_merge_models)
        when 'freshcaller'
          @klasses = ['User']
          @es_search_term = sanitized_search_term(params[:term])
          @search_context = :ff_contact_by_numfields
          @search_sort = 'updated_at'
          @sort_direction = 'desc'
          @items = esv2_query_results(esv2_contact_merge_models)
        when 'filteredContactSearch'
          @klasses = ['User']
          @search_context = :filtered_contact_search
          @contact_es_params = contact_es_params
          @items = esv2_query_results(esv2_contact_search_models)
        when 'filteredCompanySearch'
          @klasses = ['Company']
          @search_context = :filtered_company_search
          @items = esv2_query_results(esv2_company_search_models)
        else
          @search_sort = params[:search_sort].presence
          @sort_direction = 'desc'
          @klasses = %w[User company]
          @search_context = :agent_spotlight_customer
          @items = esv2_query_results(esv2_agent_models)
        end
        response.api_meta = { count: @items.total_entries }
        @items = [] if @count_request
      end

      private

        def decorate_objects
          company_name_mapping = Account.current.company_form.custom_company_fields.each_with_object({}) { |field, hash| hash[field.name] =  CustomFieldDecorator.display_name(field.name) }
          contact_name_mapping = Account.current.contact_form.custom_contact_fields.each_with_object({}) { |field, hash| hash[field.name] =  CustomFieldDecorator.display_name(field.name) }
          @items.map! { |item| item.is_a?(User) ? ContactDecorator.new(item, name_mapping: contact_name_mapping) : CompanyDecorator.new(item, name_mapping: company_name_mapping) }
        end

        def construct_es_params
          super.tap do |es_params|
            if @search_context == :contact_merge
              es_params[:source_id] = @source_user_id
              es_params.merge!(ES_V2_BOOST_VALUES[:contact_merge])
            elsif @search_context == :filtered_contact_search
              es_params.merge!(@contact_es_params)
            end

            unless (@search_sort.to_s == 'relevance') || @suggest
              es_params[:sort_by]         = @search_sort
              es_params[:sort_direction]  = @sort_direction
            end

            es_params[:size]  = @size
            es_params[:from]  = @offset
          end
        end

        def contact_es_params
          contact_es_params = {}
          User::CONTACT_FILTER_MAPPING.each do |filter_key, condition_hash|
            if params[filter_key]
              contact_es_params = condition_hash.clone
              break
            end
          end
          contact_es_params
        end

        def sanitized_search_term(es_search_term)
          es_search_term.match(/[[:alpha:]]/) ? es_search_term : es_search_term.gsub(/[^\d]/, '')
        end
    end
  end
end
