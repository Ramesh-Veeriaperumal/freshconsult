class ApiTicketFieldsController < ApiApplicationController
  skip_before_filter :load_objects
  before_filter :validate_params, :load_objects, only: [:index]

  def index
    @account = current_account
    super
  end

  private

    def validate_params
      params.permit(:type, *ApiConstants::DEFAULT_PARAMS)
      @errors = [[:type, ["can't be blank"]]] if
        params[:type] && ApiTicketConstants::TICKET_FIELD_TYPES.exclude?(params[:type])
      render_error @errors if @errors
    end

    def scoper
      filter = params[:type] ? { field_type: params[:type] } : {}
      filter_on_products(current_account.ticket_fields).where(filter).includes(:nested_ticket_fields)      
    end

    def filter_on_products(tkt_fields)
      if exclude_products
        tkt_fields.where(['helpdesk_ticket_fields.field_type != ?', 'default_product'])
      else
        tkt_fields
      end
    end

    def exclude_products
      (!current_portal.main_portal || current_account.products_from_cache.empty?)
    end
end
