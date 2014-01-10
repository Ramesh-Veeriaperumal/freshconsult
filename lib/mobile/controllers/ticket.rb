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
        if field.field_type == "default_agent"
          field[:agent_groups] = agent_group_map
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

  def top_view
      dynamic_views = scoper_user_filters.map { |i| {:id => i[:id], :name => i[:name], :default => false} }
      default_views = [
        { :id => "new_my_open",  :name => t("helpdesk.tickets.views.new_my_open"),     :default => true },
        { :id => "all_tickets",  :name => t("helpdesk.tickets.views.all_tickets"),     :default => true },
        { :id => "monitored_by", :name => t("helpdesk.tickets.views.monitored_by"),    :default => true },
        { :id => "spam"   ,      :name => t("helpdesk.tickets.views.spam"),            :default => true },
        { :id => "deleted",      :name => t("helpdesk.tickets.views.deleted"),         :default => true }
      ]
      top_views_array = [].concat(default_views).concat(dynamic_views)
      top_views_array;
  end
    
  def get_summary_count
      summary_count_array = [
        { :id => "overdue",    :value => filter_count(:overdue),      :name => t("helpdesk.dashboard.summary.overdue")},
        { :id => "open",       :value => filter_count(:open),         :name => t("helpdesk.dashboard.summary.open")},
        { :id => "on_hold",    :value => filter_count(:on_hold),      :name => t("helpdesk.dashboard.summary.on_hold")},
        { :id => "due_today",  :value => filter_count(:due_today),    :name => t("helpdesk.dashboard.summary.due_today")},
        { :id => "new",        :value => filter_count(:new),          :name => t("helpdesk.dashboard.summary.unassigned")}
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
