# encoding: utf-8
module Mobile::Controllers::Ticket

  include TicketsFilter

  def ticket_props
    is_new =  params[:id].nil?
    item = current_account.tickets.find_by_display_id(params[:id]) unless params[:id].nil?
    fields = []
    all_fields = current_portal.ticket_fields_including_nested_fields if current_user.agent?
    all_fields.each do |field|
      next if field.section_field? || field.field_type == "default_company"
      if field.visible_in_view_form? || is_new        
        
        getField(field, item)
        
        #For Agent Field     
        field[:agent_groups] = agent_group_map if field.field_type == "default_agent"                
        
        #Dynamic Sections  
        # field[:has_sections] = field.has_section? ? true : false
        field[:sections] = sectionFields(field,item)

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

  def sectionFields field, item

    sectionsList = []
    #For each section in Dynamic Form
    field.picklist_values.includes(:section).each do |picklist|
     
      section = {}
      section[:name] = picklist.value            
      next if picklist.section.blank?   

      fields =[]     
      #For each Field in each Section
      picklist.section_ticket_fields.each do |field|             
        getField(field, item)
        fields.push(field)        
      end 
      section[:fields] = fields      
      sectionsList.push(section)
    end
    sectionsList
  end 

#return Field object with properties needed for Mobile 
def getField field, item
    field_value = item.send(field.field_name) unless item.nil?
    dom_type    = (field.field_type == "default_source") ? "dropdown" : field.dom_type
    dom_type = "dropdown_blank" if field.field_type == "nested_field"
    if(field.field_type == "nested_field" && !item.nil?)
      field_value = {}
      field.nested_levels.each do |ff|
        field_value[(ff[:level] == 2) ? :subcategory_val : :item_val] = item.send(ff[:name])
      end
      field_value.merge!({:category_val => item.send(field.field_name)})
    end   
    field[:nested_choices] = field.nested_field? ? field.nested_choices : nil 
    field[:nested_levels] = field.nested_field? ? field.nested_levels : nil
    field[:field_value] = field_value
    field[:choices] = field.choices #TODO try to use to_json
    field[:domtype] = dom_type
    field[:is_default_field] = field.is_default_field?
    field[:field_name] = field.field_name     
    field
end 

  def top_view
      dynamic_views = scoper_user_filters.map { |i| {:id => i[:id], :name => i[:name], :default => false} }
      default_views = TicketsFilter.default_views
      
      # Removing 'Archive' filter from the list. Will be handled in Phase 2
      default_views.delete_if{ |view| view[:id] == "archived" }
      
      [].concat(default_views).concat(dynamic_views)
  end
    
  def get_summary_count
      summary_count_array = [
        { :id => "overdue",    :value => filter_count(:overdue, true),      :name => t("helpdesk.dashboard.summary.overdue")},
        { :id => "open",       :value => filter_count(:open, true),         :name => t("helpdesk.dashboard.summary.open")},
        { :id => "on_hold",    :value => filter_count(:on_hold, true),      :name => t("helpdesk.dashboard.summary.on_hold")},
        { :id => "due_today",  :value => filter_count(:due_today, true),    :name => t("helpdesk.dashboard.summary.due_today")},
        { :id => "new",        :value => filter_count(:new, true),          :name => t("helpdesk.dashboard.summary.unassigned")}
      ]
      summary_count_array;
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

  def twitter_handles_map
    twitter_handle = current_account.twitter_handles.map { |handle| {:id => handle.id, :name => handle.formatted_handle}}
  end

  def agent_group_map
    result = []
    current_account.agents_from_cache.each { |c| 
      result.push( 
        :agent_id => c.user.id,
        :group_ids => c.agent_groups.collect { |grp| grp.group_id})
    }
    return result
  end
end
