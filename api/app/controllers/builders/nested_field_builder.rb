module NestedFieldBuilder
  include Admin::TicketFieldConstants
  include Admin::TicketFields::CommonHelper
  include UtilityHelper

  def create_nested_field_and_level(attrs)
    attrs[:position] = cname_params[:position] || 1 # to have position for flexifield so it passes validation
    cname_params[:type] = :nested_field
    created_params = build_params(HELPDESK_NESTED_TICKET_FIELD_CREATE_PARAMS, attrs)
    nested_field = @item.nested_ticket_fields.build(created_params)
    child_level = @item.child_levels.new
    child_level_tf_param = map_ticket_field_params(child_level, TICKET_FIELD_PARAMS, attrs)
    child_level.assign_attributes(child_level_tf_param.merge(level: attrs[:level]))
    nested_field.flexifield_def_entry = child_level.flexifield_def_entry = create_flexifield_entry(child_level_tf_param)
    nested_field.name = child_level.name
  end

  def update_nested_field_and_level(nested_field, child_level, data)
    data = deep_symbolize_keys(data)
    if data[:deleted].present?
      nested_field.mark_for_destruction
      child_level.mark_for_destruction
      return
    end
    nested_field.assign_attributes(build_params(HELPDESK_NESTED_TICKET_FIELD_UPDATE_PARAMS, data))
    child_level.assign_attributes(build_params(HELPDESK_NESTED_TICKET_FIELD_UPDATE_PARAMS, data))
    child_level.assign_attributes(map_ticket_field_params(child_level, TICKET_FIELD_PORTAL_PARAMS, data))
  end

  def associate_child_levels_and_dependent_fields
    helpdesk_nested_field = @item.nested_ticket_fields
    child_levels = @item.child_levels
    cname_params[:dependent_fields].each do |dependent_field|
      if dependent_field[:id].present?
        nested_field = helpdesk_nested_field.find { |field| field.level == dependent_field[:level] }
        nested_level = child_levels.find { |level| level.id == dependent_field[:id] }
        data = dependent_field.reject { |key| key == :id }
        update_nested_field_and_level(nested_field, nested_level, data)
      else
        create_nested_field_and_level(dependent_field)
      end
    end
  end
end
