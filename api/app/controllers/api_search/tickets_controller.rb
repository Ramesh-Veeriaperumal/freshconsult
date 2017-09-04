module ApiSearch
  class TicketsController < SearchController
  
    def index
      tree = parser.expression_tree
      record = record_from_expression_tree(tree)

      record = sanitize_custom_fields(record, ApiSearchConstants::TICKET_FIELDS)

      validation_params = record.merge({ticket_fields: ticket_fields })
      validation_params.merge!(statuses: Helpdesk::TicketStatus.status_objects_from_cache(current_account))
      validation = Search::TicketValidation.new(validation_params, ticket_custom_fields)
      
      if validation.valid?
        @name_mapping = custom_fields
        search_terms = tree.accept(visitor)
        page = params[:page] ? params[:page].to_i : ApiSearchConstants::DEFAULT_PAGE
        @items = query_results(search_terms, page, ApiSearchConstants::TICKET_ASSOCIATIONS, ['ticket'])
      else
        render_custom_errors(validation, true)
      end
    end

    private
    
      def custom_fields
        @custom_fields ||= Account.current.ticket_field_def.ff_alias_column_mapping.each_with_object({}) {|(key,value), hash| hash[key] = TicketDecorator.display_name(key) }
      end

      def visitor
        column_names = Account.current.ticket_field_def.ff_alias_column_mapping.each_with_object({}) {|(key,value), hash| hash[TicketDecorator.display_name(key).to_sym] = value if value=~ ApiSearchConstants::TICKET_FIELDS_REGEX }.except(*ApiSearchConstants::TICKET_FIELDS.map(&:to_sym))
        column_names.merge!({ fr_due_by: :frDueBy })
        Search::TermVisitor.new(column_names)
      end

      def allowed_custom_fields
        # If any custom fields have the name same as that of default fields it will be ignored
        ticket_custom_fields.each_with_object({}) { |ticket_field, hash| hash[ticket_field.name] = TicketDecorator.display_name(ticket_field.name) unless ApiSearchConstants::TICKET_FIELDS.include?(TicketDecorator.display_name(ticket_field.name)) }
      end

      def ticket_custom_fields
        ticket_fields.select{|x| ApiSearchConstants::ALLOWED_CUSTOM_FIELD_TYPES.include? x.field_type }
      end

      def ticket_fields
        Account.current.ticket_fields_from_cache
      end
  end
end