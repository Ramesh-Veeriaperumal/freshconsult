module ApiSearch
  class TicketsController < SearchController
    decorate_views
    def index
      response = Freshquery::Runner.instance.construct_es_query('ticket',params[:query])
      if response.valid?
        page = params[:page] ? params[:page].to_i : ApiSearchConstants::DEFAULT_PAGE
        @items = query_results(response.terms, page, ApiSearchConstants::TICKET_ASSOCIATIONS, ['ticket'])
      else
        render_errors response.errors, response.error_options
      end
    end

    private

      def decorator_options
        super({ name_mapping: Account.current.ticket_field_def.ff_alias_column_mapping.each_with_object({}) { |(key, value), hash| hash[key] = TicketDecorator.display_name(key) } })
      end
  end
end
