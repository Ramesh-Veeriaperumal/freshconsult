module ApiSearch
  class TicketsController < SearchController
  
    def index
      tree = parser.expression_tree
      record = record_from_expression_tree(tree)

      sanitize_custom_fields(record, ApiSearchConstants::TICKET_FIELDS) if custom_fields.any?

      validation_params = record.merge({ticket_fields: ticket_fields })
      validation_params.merge!(statuses: Helpdesk::TicketStatus.status_objects_from_cache(current_account))
      validation = Search::TicketValidation.new(validation_params, ticket_custom_fields)
      
      if validation.valid?
        @name_mapping = custom_fields
        search_terms = tree.accept(visitor)
        page = params[:page] ? params[:page].to_i : 1
        response = query_es(search_terms, :tickets, page)
        @items = query_results(response, page, ApiSearchConstants::TICKET_ASSOCIATIONS)
      else
        render_custom_errors(validation, true)
      end
    end

    private

      def custom_fields
        @custom_fields ||= ticket_custom_fields.each_with_object({}) { |ticket_field, hash| hash[ticket_field.name] = TicketDecorator.display_name(ticket_field.name) }
      end

      def visitor
        column_names = ticket_custom_fields.each_with_object({}) { |ticket_field, hash| hash[TicketDecorator.display_name(ticket_field.name).to_sym] = ticket_field.column_name }
        Search::TermVisitor.new(column_names)
      end

      def ticket_custom_fields
        ticket_fields.select{|x| ApiSearchConstants::ALLOWED_CUSTOM_FIELD_TYPES.include? x.field_type }
      end

      def ticket_fields
        Account.current.ticket_fields_from_cache
      end
  end
end
