class Admin::TicketFieldsController < ApiApplicationController
  include Admin::TicketFieldHelper

  before_filter :validate_ticket_field, except: [:index]

  decorate_views(decorate_objects: [:index])

  def load_object
    @item = current_account.ticket_fields_with_nested_fields.find_by_id(params[:id])
    log_and_render_404 unless @item
  end

  def scoper
    current_account.ticket_fields_with_nested_fields
  end

  def destroy
    @item.destroy
    head 204
  end

  private

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
