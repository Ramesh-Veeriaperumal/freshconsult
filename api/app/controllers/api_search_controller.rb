class ApiSearchController < ApiApplicationController
  include SearchHelper

  actions = [:tickets, :contacts, :companies]

  before_filter :validate_url_params, only: actions

  actions.each do |method_name|
    define_method(method_name) do
      search(method_name.to_s.singularize)
    end
  end

  def search(resource)
    tree = parser.expression_tree
    record = ActionController::Parameters.new
    tree.each do |node|
      if node.type == :operand
        record[node.key] = [] unless record[node.key]
        record[node.key] += [node.value]
      end
    end

    sanitize_custom_fields(record, resource) if custom_fields(resource).any?

    validation = "Search::#{resource.capitalize}Validation".constantize.new(record.merge({"#{resource}_fields".to_sym => allowed_fields(resource)}))
    
    if validation.valid?
      search_terms = tree.accept(visitor(resource))
      ids = ids_from_esv2_response(query_es(search_terms, resource.pluralize.to_sym))

      @items = ids.any? ? paginate_items(send("#{resource}_scoper").where(id: ids)) : []
      @name_mapping = custom_fields(resource)
    else
      render_custom_errors(validation, true)
    end
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

    def sanitize_custom_fields(record, resource)
      record.permit(*"ApiSearchConstants::#{resource.upcase}_FIELDS".constantize | custom_fields(resource).values)

      record[:custom_fields] = {}
      custom_fields(resource).each do |field_name, display_name|
        if record.key?(display_name)
          record[:custom_fields][field_name] = record.delete(display_name)
        end
      end
    end

    def visitor(resource)
      @visitor ||= Search::TermVisitor.new(column_names(resource), resource)
    end

    def allowed_fields(resource)
      @allowed_fields ||= SearchValidationHelper.send("#{resource}_fields")
    end

    def custom_fields(resource)
      @custom_fields ||= SearchValidationHelper.send("#{resource}_field_names")
    end

    def column_names(resource)
      @column_names ||= SearchValidationHelper.send("#{resource}_field_column_names")
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

    def contact_scoper
      current_account.all_contacts.preload(:flexifield, :default_user_company)
    end

    def company_scoper
      current_account.companies.preload(:flexifield, :company_domains)
    end
end