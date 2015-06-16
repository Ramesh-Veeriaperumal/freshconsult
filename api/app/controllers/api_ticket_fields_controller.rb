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
      @errors = [[:type, "can't be blank"]] if
        params[:type] && ApiConstants::TICKET_FIELD_TYPES.exclude?(params[:type])
      render_error @errors if @errors
    end

    def scoper
      filter = params[:type] ? { field_type: params[:type] } : {}
      current_account.ticket_fields.where(filter).includes(:nested_ticket_fields)
    end
end
