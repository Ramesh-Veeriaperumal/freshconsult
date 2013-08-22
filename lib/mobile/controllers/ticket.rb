# encoding: utf-8
module Mobile::Controllers::Ticket
  def ticket_props
    is_new =  params[:id].nil?
    item = current_account.tickets.find_by_display_id(params[:id]) unless params[:id].nil?
    fields = []
    all_fields = current_portal.ticket_fields if current_user.agent?
    all_fields.each do |field|
      if field.visible_in_view_form? || is_new
        field_value = item.send(field.field_name) unless item.nil?
        dom_type    = (field.field_type == "default_source") ? "dropdown" : field.dom_type
        if(field.field_type == "nested_field" && !item.nil?)
          field_value = {}
          field.nested_levels.each do |ff|
            field_value[(ff[:level] == 2) ? :subcategory_val : :item_val] = item.send(ff[:name])
          end
          field_value.merge!({:category_val => item.send(field.field_name)})
        end
        field[:nested_choices] = field.nested_choices
        field[:nested_levels] = field.nested_levels
        field[:field_value] = field_value
        field[:choices] = field.choices #TODO try to use to_json
        field[:domtype] = dom_type
        field[:is_default_field] = field.is_default_field?
        field[:field_name] = field.field_name
        fields.push(field)
        #populating cc field
        if ( is_new and
            ( field.dom_type.eql?("requester") || ( field.dom_type.eql?('email') && field.portal_cc_field? ) ) )
          add_cc_field(fields,field)
        end
      end
    end
	return fields
  end

  private
    def add_cc_field fields, field
      if current_user.agent?
          fields.push(:ticket_field => {
            :field_value => "",
            :domtype => field.dom_type,
            :nested_choices => [],
            :nested_levels => nil,
            :choices => [],
            :is_default_field => true,
            :field_name => "cc_emails",
            :label => "Cc ",
            :is_cc_field => true
          });
      end
    end
end
