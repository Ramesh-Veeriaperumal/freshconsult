class ApiTicketFieldsController < ApiApplicationController
  private

    def validate_filter_params
      params.permit(:type, *ApiConstants::DEFAULT_PARAMS)
      errors = [[:type, ["can't be blank"]]] if params.key?(:type) && ApiTicketConstants::FIELD_TYPES.exclude?(params[:type])
      render_errors errors if errors
    end

    def scoper
      condition = '2 > 1'
      condition += " AND field_type = \"#{params[:type]}\"" if params[:type]
      condition += ' AND helpdesk_ticket_fields.field_type != "default_product"' if exclude_products
      current_account.ticket_fields.where(condition).includes(:nested_ticket_fields)
    end

    def exclude_products
      (!current_portal.main_portal || current_account.products_from_cache.empty?)
    end
end
