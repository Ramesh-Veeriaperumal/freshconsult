class ApiTicketFieldsController < ApiApplicationController
  private

    def validate_filter_params
      params.permit(:type, *ApiConstants::DEFAULT_INDEX_FIELDS)
      ticket_field_filter = ApiTicketFieldFilterValidation.new(params, nil, true)
      render_errors(ticket_field_filter.errors, ticket_field_filter.error_options) unless ticket_field_filter.valid?
    end

    def scoper
      condition = []
      condition << "field_type = \"#{params[:type]}\"" if params[:type]
      condition << 'helpdesk_ticket_fields.field_type != "default_product"' if exclude_products
      current_account.ticket_fields.where(condition.join(' AND ')).preload(:nested_ticket_fields)
    end

    def exclude_products
      (!current_portal.main_portal || current_account.products_from_cache.empty?)
    end
end
