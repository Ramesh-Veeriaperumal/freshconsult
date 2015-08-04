class TicketFieldsController < CustomFieldsController

  include TicketFieldsHelper

  def index
    @ticket_fields = current_portal.ticket_fields
    @section_data = current_account.sections

    respond_to do |format|
      format.html {
        @ticket_field_json = ticket_field_hash(@ticket_fields, current_account)
        @section_data_json = section_data_hash(@section_data, current_account)
      }
      format.xml  { render :xml => @ticket_fields.to_xml }
      format.json  { render :json => @ticket_fields }
    end
  end

  private
    def edit_nested_field(ticket_field,nested_field)
      nested_field.delete(:type)
      nested_field.delete(:position)
      nested_ticket_field = ticket_field.nested_ticket_fields.find(nested_field.delete(:id))
      @invalid_fields.push(ticket_field) and return unless nested_ticket_field.update_attributes(nested_field)
    end

    def delete_nested_field(ticket_field,nested_field)
      nested_ticket_field = ticket_field.nested_ticket_fields.find(nested_field[:id])
      nested_ticket_field.destroy if nested_ticket_field
    end
end
