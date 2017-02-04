module Ember
  module Search
    class CustomersController < SpotlightController

      def results
        if params[:context] == 'spotlight'
          @klasses = %w(User company)
          @search_context = :agent_spotlight_customer
          @items = esv2_query_results(esv2_agent_models)
        elsif params[:context] == 'merge'

          # Only Contact Merge

          @klasses = ['User']
          @source_user_id	= params[:source_user_id]
          @search_context = :contact_merge
          @items = esv2_query_results(esv2_contact_merge_models)
        end

        response.api_meta = { count: @items.count }
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
            end

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
