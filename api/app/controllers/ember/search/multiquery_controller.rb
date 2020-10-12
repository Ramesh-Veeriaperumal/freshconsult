module Ember
  module Search
    class MultiqueryController < SpotlightController

      before_filter :sanitize_params, :validate_params
      before_filter :ignore_params # Hack for forums, to be removed when forums feature has been migrated to bitmap
      decorate_views(decorate_objects: [:search_results])

      def search_results
        @search_sort = params[:search_sort].presence
        @sort_direction = 'desc'
        @query_contexts = params[:templates].map do |template|
          @search_context = template.underscore.to_sym
          @type           = template_type(template)
          @klasses        = ::Search::Utils::TEMPLATE_TO_CLASS_MAPPING[@search_context]
          construct_query
        end
        @records = es_multiquery_results
        meta = {}
        meta[:count] = Hash.new.tap do |count|
          @records.each do |record|
            count[record[:context]] = record[:data].total_entries
          end
        end
        response.api_meta = meta
      end

      private

        def sanitize_params
          params[:limit] = params[:limit].to_i if params[:limit]
        end

        def validate_params
          @search_validation = SearchValidation.new(params)
          render_custom_errors(@search_validation, true) unless @search_validation.valid?
        end

        def ignore_params # Hack for forums, to be removed when forums feature has been migrated to bitmap
          valid, @invalid_templates = @search_validation.template_features
          @invalid_templates.each { |t| params[:templates].delete(t) } unless valid
        end

        def decorate_objects
          @items = {}
          @records.each do |record|
            @items[record[:context]] = safe_send("decorate_#{template_type(record[:context])}_objects", record[:data])
          end
        end

        def construct_query
          @query_handler = ::Search::V2::QueryHandler.new({
            account_id:   current_account.id,
            context:      @search_context,
            exact_match:  @exact_match,
            es_models:    esv2_agent_models,
            types:        searchable_types,
            es_params:    construct_mq_es_params,
            locale:       @es_locale,
            templates:    params[:templates]
          })
          @query_handler.construct_query
        end

        def construct_mq_es_params
          {
            :account_id => current_account.id,
            :request_id => request.try(:uuid),
            :size       => @size,
            :offset     => @offset
          }.merge(es_additional_params).merge(send("construct_mq_#{@type}_params"))
        end

        def es_multiquery_results
          request_params = {
            :search_term    => @es_search_term,
            :limit          => @mq_limit,
            :query_contexts => Array.wrap(@query_contexts)
          }.to_json
          response = @query_handler.multi_query_results(request_params)
          # Hack for forums, to be removed when forums feature has been migrated to bitmap
          data = ::Search::V2::PaginationWrapper.new([], { page: nil, from: 0, total_entries: 0 })
          @invalid_templates.each do |template|
            response.push({:context => template, :data => data})
          end
          response
        end

        def construct_mq_ticket_params
          Hash.new.tap do |es_params|
            if current_user.restricted?
              es_params[:restricted_responder_id] = current_user.id.to_i
              es_params[:restricted_group_id] = current_user.agent_groups.map(&:group_id) if current_user.group_ticket_permission

              if current_account.shared_ownership_enabled?
                es_params[:restricted_internal_agent_id] = current_user.id.to_i
                es_params[:restricted_internal_group_id] = current_user.agent_groups.map(&:group_id) if current_user.group_ticket_permission
              end
            end
          end
        end

        def construct_mq_solution_params
          Hash.new.tap do |es_params|
            es_params[:language_id] = params[:language].present? && current_account.es_multilang_solutions_enabled? ? params[:language] : Language.for_current_account.id
          end
        end

        def construct_mq_topic_params
          Hash.new
        end

        def construct_mq_customer_params
          Hash.new
        end

        def template_type(template)
          template.underscore.split('_').last if template.present?
        end

        def decorate_ticket_objects(objects)
          options = { sideload_options: ['requester', 'company'] }
          objects.map { |object| TicketDecorator.new(object, options) }
        end

        def decorate_customer_objects(objects)
          company_name_mapping = Account.current.company_form.custom_company_fields.each_with_object({}) { |field, hash| hash[field.name] =  CustomFieldDecorator.display_name(field.name) }
          contact_name_mapping = Account.current.contact_form.custom_contact_fields.each_with_object({}) { |field, hash| hash[field.name] =  CustomFieldDecorator.display_name(field.name) }
          objects.map { |object| object.is_a?(User) ? ContactDecorator.new(object, name_mapping: contact_name_mapping) : CompanyDecorator.new(object, name_mapping: company_name_mapping) }
        end

        def decorate_topic_objects(objects)
          objects.map { |object| ::Discussions::TopicDecorator.new(object, {}) }
        end

        def decorate_solution_objects(objects)
          objects.map { |object| ::Solutions::ArticleDecorator.new(object, {}) }
        end


    end
  end
end
