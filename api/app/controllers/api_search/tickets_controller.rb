module ApiSearch
  class TicketsController < SearchController
    decorate_views
    def index
      fq_builder = Freshquery::Builder.new.query do |builder|
        builder[:account_id]    = current_account.id
        builder[:context]       = :search_ticket_api
        builder[:current_page]  = params[:page] ? params[:page].to_i : ApiSearchConstants::DEFAULT_PAGE
        builder[:types]         = ['ticket']
        builder[:es_models]     = ApiSearchConstants::TICKET_ASSOCIATIONS
        builder[:es_params]     = es_params
        builder[:query]         = params[:query]
      end
      response = fq_builder.records
      if response.valid?
        @items = response.items
      else
        render_errors response.errors, response.error_options
      end
    end

    private

      def decorator_options
        super({ name_mapping: Account.current.ticket_field_def.ff_alias_column_mapping.each_with_object({}) { |(key, value), hash| hash[key] = TicketDecorator.display_name(key) } })
      end

      def es_params
        es_params = {}
        if current_user.restricted?
          es_params[:restricted_responder_id] = current_user.id.to_i
          es_params[:restricted_group_id]     = current_user.agent_groups.map(&:group_id) if current_user.group_ticket_permission

          if current_account.shared_ownership_enabled?
            es_params[:restricted_internal_agent_id] = current_user.id.to_i
            es_params[:restricted_internal_group_id] = current_user.agent_groups.map(&:group_id) if current_user.group_ticket_permission
          end
        end
        es_params
      end
  end
end
