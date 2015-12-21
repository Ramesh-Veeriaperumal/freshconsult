class ApiTicketFieldsController < ApiApplicationController
  private

    def validate_filter_params
      params.permit(:type, *ApiConstants::DEFAULT_PARAMS)
      errors = [[:type, :blank]] if params.key?(:type) && ApiTicketConstants::FIELD_TYPES.exclude?(params[:type])
      render_errors errors if errors
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
