class Admin::TicketFieldsController < ApiApplicationController
  include Admin::TicketFieldHelper
  include Admin::TicketFieldConstants

  before_filter :validate_ticket_field
  before_filter :ticket_field_id_sections, :ticket_field_id_dependent_fields

  decorate_views(decorate_objects: [:index])

  def load_object
    @item = current_account.ticket_fields_with_nested_fields.find_by_id(params[:id])
    @decorated_item = @item && Admin::TicketFieldDecorator.new(@item, include: params[:include])
    log_and_render_404 unless @item
  end

  def load_objects(items = scoper)
    # This method has been overridden to avoid pagination.
    @items = items
    @decorated_items = items.map { |item| Admin::TicketFieldDecorator.new(item, include: params[:include]) }
  end

  def scoper
    current_account.ticket_fields_from_cache.select(&:condition_based_field)
  end

  def destroy
    @item.destroy
    head 204
  end

  private

    def validate_url_params
      params.permit(*SHOW_FIELDS)
    end

    def validate_filter_params
      params.permit(*INDEX_FIELDS)
    end

    def launch_party_name
      FeatureConstants::TICKET_FIELD_REVAMP
    end

    def validate_ticket_field
      run_validation
    end

    def delegation_class
      'Admin::TicketFieldsDelegator'.constantize
    end

    def validation_class
      'Admin::TicketFieldsValidation'.constantize
    end
end
