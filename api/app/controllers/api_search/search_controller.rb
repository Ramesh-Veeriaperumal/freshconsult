module ApiSearch
  class SearchController < ApiApplicationController
    include SearchHelper

    private
      def validate_filter_params
        params.permit(*ApiSearchConstants::FIELDS, *ApiSearchConstants::DEFAULT_INDEX_FIELDS)
        @url_validation = SearchUrlValidation.new(params)
        render_errors @url_validation.errors, @url_validation.error_options unless @url_validation.valid?
      end

      def query_results(search_terms, page, associations, type)
        begin
          @records = Search::V2::QueryHandler.new(
            account_id:   current_account.id,
            context:      fetch_context(type),
            exact_match:  false,
            es_models:    associations,
            current_page: page,
            offset:       ApiSearchConstants::DEFAULT_PER_PAGE,
            types:        type,
            es_params:    construct_es_params(search_terms, type, page)
          ).query_results
        rescue Exception => e
          Rails.logger.error "Searchv2 exception - #{e.message} - #{e.backtrace.first}"
          NewRelic::Agent.notice_error(e)
          @records = []
        end
        @records
      end

      def construct_es_params(search_terms, type, page)
        {}.tap do |es_params|
          es_params[:search_terms] = search_terms.to_json
          es_params[:account_id] = current_account.id
          es_params[:offset] = (page - 1) * ApiSearchConstants::DEFAULT_PER_PAGE
          es_params[:size] = ApiSearchConstants::DEFAULT_PER_PAGE
          es_params[:request_id] = Thread.current[:message_uuid].try(:first) || UUIDTools::UUID.timestamp_create.hexdigest

          if type.include?('ticket')
            if current_user.restricted?
              es_params[:restricted_responder_id] = current_user.id.to_i
              es_params[:restricted_group_id]     = current_user.agent_groups.map(&:group_id) if current_user.group_ticket_permission

              if current_account.shared_ownership_enabled?
                es_params[:restricted_internal_agent_id] = current_user.id.to_i
                es_params[:restricted_internal_group_id] = current_user.agent_groups.map(&:group_id) if current_user.group_ticket_permission
              end
            end
          end
        end
      end

      def fetch_context(type)
        if type.include?('ticket')
          return :search_ticket_api
        elsif type.include?('user')
          return :search_contact_api
        elsif type.include?('company')
          return :search_company_api
        end
      end
  end
end
