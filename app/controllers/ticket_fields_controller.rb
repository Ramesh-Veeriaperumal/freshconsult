class TicketFieldsController < CustomFieldsController

  include TicketFieldsHelper
  include Admin::AdvancedTicketing::FieldServiceManagement::Util

  def index
    @hipaa_enabled = current_account.falcon_and_encrypted_fields_enabled?
    @secure_fields_enabled = current_account.secure_fields_enabled?
    @ticket_fields = @hipaa_enabled || @secure_fields_enabled ? current_portal.ticket_fields_including_nested_fields : current_portal.ticket_fields_including_nested_fields(:non_encrypted_ticket_fields)
    @section_data = current_account.sections
    @fsm_fields = fsm_custom_field_to_reserve
    support_groups = current_account.groups_from_cache.select{ |group| group.group_type == GroupType.group_type_id(GroupConstants::SUPPORT_GROUP_NAME)}
    respond_to do |format|
      format.html {
        @ticket_field_json = ticket_field_hash(@ticket_fields, current_account)
        @section_data_json = section_data_hash(@section_data, current_account)
        @groups = current_account.shared_ownership_enabled? ? support_groups.collect { |g| [g.id, CGI.escapeHTML(g.name)]} : []
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
      return @invalid_fields.push(ticket_field) unless nested_ticket_field.update_attributes(nested_field)
      # Currently updating by comparing the name of the nested_ticket_field
      # This should be changed once 'id' is populated for the child_levels in the UI
      child_level = ticket_field.child_levels.find_by_name(nested_ticket_field.name)
      child_level.update_attributes(nested_field) if child_level
    end

    def delete_nested_field(ticket_field,nested_field)
      nested_ticket_field = ticket_field.nested_ticket_fields.find(nested_field[:id])
      if nested_ticket_field
        nested_ticket_field.destroy
        # Currently destorying by comparing the name of the nested_ticket_field
        # This should be changed once 'id' is populated for the child_levels in the UI
        child_level = ticket_field.child_levels.find_by_name(nested_ticket_field.name)
        child_level.try(:destroy)
      end
    end
end
