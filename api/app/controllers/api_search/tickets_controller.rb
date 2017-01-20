module ApiSearch
  class TicketsController < SearchController
  
    def index
      tree = parser.expression_tree
      record = record_from_expression_tree(tree)

      record = sanitize_custom_fields(record, ApiSearchConstants::TICKET_FIELDS) if custom_fields.any?

      validation_params = record.merge({ticket_fields: ticket_fields })
      validation_params.merge!(statuses: Helpdesk::TicketStatus.status_objects_from_cache(current_account))
      validation = Search::TicketValidation.new(validation_params, ticket_custom_fields)
      
      if validation.valid?
        @name_mapping = custom_fields
        search_terms = tree.accept(visitor)
        page = params[:page] ? params[:page].to_i : ApiSearchConstants::DEFAULT_PAGE
        @items = query_results(search_terms, page, ApiSearchConstants::TICKET_ASSOCIATIONS, 'ticket')
      else
        render_custom_errors(validation, true)
      end
    end

    private
    
      def custom_fields
        @custom_fields ||= Account.current.ticket_field_def.ff_alias_column_mapping.each_with_object({}) {|(key,value), hash| hash[key] = TicketDecorator.display_name(key) if value=~ ApiSearchConstants::TICKET_FIELDS_REGEX }
      end

      def visitor
        column_names = Account.current.ticket_field_def.ff_alias_column_mapping.each_with_object({}) {|(key,value), hash| hash[TicketDecorator.display_name(key).to_sym] = value if value=~ ApiSearchConstants::TICKET_FIELDS_REGEX }
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