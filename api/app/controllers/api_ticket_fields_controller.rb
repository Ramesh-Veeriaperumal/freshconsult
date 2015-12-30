class ApiTicketFieldsController < ApiApplicationController
  decorate_views

  private

    def validate_filter_params
      params.permit(:type, *ApiConstants::DEFAULT_INDEX_FIELDS) # We will allow pagination options, but they will be ignored, to be consistent with contact/company fields.
      errors = [[:type, :not_included]] if params.key?(:type) && ApiTicketConstants::FIELD_TYPES.exclude?(params[:type])
      render_errors errors, {list: ApiTicketConstants::FIELD_TYPES.join(', ')} if errors
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

    def load_objects(items = scoper)
      # This method has been overridden to avoid pagination.
      @items = items
    end
end
