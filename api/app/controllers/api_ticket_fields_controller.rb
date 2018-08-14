class ApiTicketFieldsController < ApiApplicationController
  decorate_views

  include MemcacheKeys

  PRELOAD_ASSOC = [:nested_ticket_fields].freeze

  private

    def validate_filter_params
      params.permit(:type, *ApiConstants::DEFAULT_INDEX_FIELDS) # We will allow pagination options, but they will be ignored, to be consistent with contact/company fields.
      errors = [[:type, :not_included]] if params.key?(:type) && allowed_field_types.exclude?(params[:type])
      render_errors errors, list: allowed_field_types.join(', ') if errors
    end

    def scoper
      @ticket_fields_full_mem_key =TICKET_FIELDS_FULL % { :account_id => current_account.id }
      @ticket_fields_full_cache_data = MemcacheKeys.get_from_cache(@ticket_fields_full_mem_key)
      return [] if @ticket_fields_full_cache_data != nil
      @ticket_fields_full_cache_data = nil
      condition = []
      condition << "field_type = \"#{params[:type]}\"" if params[:type]
      condition << 'helpdesk_ticket_fields.field_type != "default_product"' if exclude_products
      current_account.ticket_fields_only.where(condition.join(' AND ')).preload(self.class::PRELOAD_ASSOC)
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
end
