class ApiSearchController < ApiApplicationController
  include SearchHelper

  before_filter :validate_url_params, only: [:tickets]

  def tickets
    @query = params[:query]
    tree = parser.expression_tree
    record = ActionController::Parameters.new
    tree.each do |node|
      if node.type == :operand
        record[node.key] = [] unless record[node.key]
        record[node.key] += [node.value]
      end
    end

    sanitize_custom_fields(record) if custom_fields.any?

    ticket_validation = Search::TicketValidation.new(record.merge({ticket_fields: ticket_fields}))
    render_custom_errors(ticket_validation, true) unless ticket_validation.valid?

    search_terms = tree.accept(visitor)
    ticket_ids = ids_from_esv2_response(query_es(search_terms, :tickets))

    @items = paginate_items(ticket_ids.any? ? ticket_scoper.where(id: ticket_ids) : [])
    @name_mapping = custom_fields
  end

  private

    def validate_url_params
      params.permit(*ApiSearchConstants::FIELDS, *ApiConstants::DEFAULT_INDEX_FIELDS)
      @url_validation = SearchUrlValidation.new(params, parser)
      render_errors @url_validation.errors, @url_validation.error_options unless @url_validation.valid?
    end

    def load_object
      # Override base class method
    end

    def sanitize_custom_fields(record)
      record.permit(*ApiSearchConstants::TICKET_FIELDS | custom_fields.values)
      
      record[:custom_fields] = {}
      custom_fields.each do |field_name, display_name|
        if record.key?(display_name)
          record[:custom_fields][field_name] = record.delete(display_name)
        end
      end
    end

    def visitor
      @visitor ||= Search::TermVisitor.new(column_names, parser)
    end

    def ticket_fields
      @ticket_fields ||= Account.current.ticket_fields_from_cache
    end

    def custom_fields
      @custom_fields ||= SearchValidationHelper.ticket_field_names
    end

    def column_names
      @column_names ||= SearchValidationHelper.ticket_field_column_names
    end

    def parser
      @parser ||= Search::V2::Parser::SearchParser.new
    end

    def set_custom_errors(item)
      ErrorHelper.rename_error_fields(@custom_fields, item)
    end

    def error_options_mappings
      @custom_fields
    end

    def ticket_scoper
      current_account.tickets.preload([:ticket_old_body, :schema_less_ticket, :flexifield])
    end
end