class ApiTicketFieldsController < ApiApplicationController
  decorate_views

  PRELOAD_ASSOC = [:nested_ticket_fields, :picklist_values].freeze

  private

    def validate_filter_params
      params.permit(:type, *ApiConstants::DEFAULT_INDEX_FIELDS) # We will allow pagination options, but they will be ignored, to be consistent with contact/company fields.
      errors = [[:type, :not_included]] if params.key?(:type) && allowed_field_types.exclude?(params[:type])
      render_errors errors, list: allowed_field_types.join(', ') if errors
    end

    def scoper
      condition = []
      condition << "field_type = \"#{params[:type]}\"" if params[:type]
      condition << 'helpdesk_ticket_fields.field_type != "default_product"' if exclude_products
      current_account.ticket_fields_only.where(condition.join(' AND ')).preload(preload_assoc)
    end

    def exclude_products
      (!current_portal.main_portal || current_account.products_from_cache.empty?)
    end

    def allowed_field_types
      current_account.shared_ownership_enabled? ?
          ApiTicketConstants::FIELD_TYPES :
          ApiTicketConstants::FIELD_TYPES - ['default_internal_group', 'default_internal_agent']
    end

    def load_objects(items = scoper)
      # This method has been overridden to avoid pagination.
      @items = items
    end

    def preload_assoc
      self.class::PRELOAD_ASSOC
    end
end
