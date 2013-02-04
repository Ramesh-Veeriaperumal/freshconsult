module Admin::RolesHelper
  
  ROLE_SECTIONS = 
    [

      # *************************** Tickets **************************

      { :dom_type => "label", :id => "tickets",
        :children => 

          [{ :dom_type => "hidden_field", :id => "manage_tickets" },
           { :dom_type => "check_box",    :id => "reply_ticket" },
           { :dom_type => "check_box",    :id => "forward_ticket" },
           { :dom_type => "check_box",    :id => "edit_note_choice",
             :privilege => "0", :class => "nested permanent_disable", 
             :children => 

              [{ :dom_type => "radio_button", :id => "edit_note" },
               { :dom_type => "radio_button", :id => "edit_note_false",
                 :privilege => "0", :class => "default" }]
           },
           { :dom_type => "check_box", :id => "edit_conversation"  },
           { :dom_type => "check_box", :id => "merge_or_split_ticket" },
           { :dom_type => "check_box", :id => "edit_ticket_properties" },
           { :dom_type => "check_box", :id => "view_time_entries", :class => "nested",
             :children => 
          
              [{ :dom_type => "radio_button", :id => "edit_time_entries" },
               { :dom_type => "radio_button", :id => "edit_time_entries_false",
                 :privilege => "0", :class => "default" }]
           },
           { :dom_type => "check_box", :id => "delete_ticket" }]
      },
            
      # *************************** Solutions **************************  
                            
      { :dom_type => "label", :id => "solutions",
        :children =>
                            
            [{ :dom_type => "check_box", :id => "view_solutions", :class => "nested",
               :children => 
                            
                [{ :dom_type => "check_box", :id => "publish_solution" },
                 { :dom_type => "check_box", :id => "delete_solution" },        
                 { :dom_type => "check_box", :id => "manage_solutions" }]
            }]
        },
                       
       # *************************** Forums **************************
                             
       { :dom_type => "label", :id => "forums",
         :children =>
                             
           [{ :dom_type => "check_box", :id => "view_forums", :class => "nested",
             :children => 
                             
               [{ :dom_type => "check_box", :id => "manage_forums" },             
                { :dom_type => "check_box", :id => "create_topic", :class => "nested",
                  :children => 
                             
                     [{ :dom_type => "radio_button", :id => "edit_topic" },
                      { :dom_type => "radio_button", :id => "edit_topic_false",
                        :privilege => "0", :class => "default" }]
                 },  
                 { :dom_type => "check_box", :id => "delete_topic" }]
           }]
       },
                             
       # *************************** Customers **************************
                             
       { :dom_type => "label", :id => "customers",
         :children =>
                             
           [{ :dom_type => "check_box", :id => "view_contacts", :class => "nested",
              :children => 
                             
               [{ :dom_type => "check_box", :id => "manage_contacts" },
                { :dom_type => "check_box", :id => "delete_contact" }]
           }]
       },
                             
       # *************************** Reports **************************
                             
       { :dom_type => "label", :id => "reports", :children => 
                             
           [{ :dom_type => "check_box", :id => "view_reports" }]
       },
                             
       # *************************** Admin **************************
                             
       { :dom_type => "label", :id => "admin",
         :children =>
                             
           [{ :dom_type => "radio_button", :id => "not_administrator",
              :privilege => "0", :class => "default"},
                             
            { :dom_type => "radio_button", :id => "operational_admin",
              :privilege => "view_admin", :class => "nested",
              :children =>
                             
                 [{ :dom_type => "check_box", :id => "manage_users" },
                  { :dom_type => "check_box", :id => "manage_canned_responses" },
                  { :dom_type => "check_box", :id => "manage_dispatch_rules" },
                  { :dom_type => "check_box", :id => "manage_supervisor_rules" },
                  { :dom_type => "check_box", :id => "manage_scenario_automation_rules" },
                  { :dom_type => "check_box", :id => "manage_email_settings" }]
                             
             },
                             
             { :dom_type => "radio_button", :id => "admin_tasks", :class => "nested",
               :children =>
                             
                 [{ :dom_type => "hidden_field", :id => "view_admin" },
                  { :dom_type => "hidden_field", :id => "manage_users" },
                  { :dom_type => "hidden_field", :id => "manage_canned_responses" },
                  { :dom_type => "hidden_field", :id => "manage_dispatch_rules" },
                  { :dom_type => "hidden_field", :id => "manage_supervisor_rules" },
                  { :dom_type => "hidden_field", :id => "manage_scenario_automation_rules" },
                  { :dom_type => "hidden_field", :id => "manage_email_settings" },
                  { :dom_type => "check_box",    :id => "manage_account" }]
                             
             }]
       }
      
    ]
  
  def build_role_form
    form = ""
    ROLE_SECTIONS.each do |section|
      
     form +=  content_tag( :div, {:class => "row-fluid margin-bottom", :id => section[:id] }) do
        content_tag( :div, content_tag( :p, t('admin.roles.privilege.'+ section[:id]), :class => "lead"), :class => "span2") +
        content_tag( :div, :class => "span10 role-section") do
          value = label(:agent, :signature_html, "<b>Agent can</b>") 
          if section[:children]
            value += process_children(section[:children], section[:id], false)
          end
          value
        end
      end
      
    end
    form
  end
  
  
  def process_children(children, parent, disabled)
    content_tag(:ul, :class => "nested-ul") do
      children.map do |child|
        content_tag(:li) do
          content_tag(:label, :class => "#{child[:dom_type]} #{style(child[:dom_type])}") do
            element = ""
            case child[:dom_type]
            when "check_box", "radio_button"
              element += build_element(child, parent, disabled)
            when "hidden_field"
              element += build_hidden(child, parent, disabled)
            end
            if child[:children]
              element += process_children(child[:children], child[:id], true) 
            end
            element
          end # label
        end # li
      end # map
    end #ul
  end
  
  private
  
    def build_element(element, parent, disabled)
      privilege = element[:privilege] || element[:id]    
      name = (element[:dom_type] == "radio_button") ? "admin_role[privilege_list][#{parent}][]" : "admin_role[privilege_list][]"
      
      html = eval "#{element[:dom_type]}_tag('#{name}', '#{privilege}',
      #{@role.abilities.include?(privilege.to_sym)}, { :class => '#{parent} #{element[:class]}',
      :id => '#{element[:id]}', :disabled => #{disabled}})" 
      html += t('admin.roles.privilege.'+ element[:id])
    end
    
    def build_hidden(element, parent, disabled)
      privilege = element[:privilege] || element[:id]
      hidden_field_tag("admin_role[privilege_list][]", privilege, 
            { :class => "#{parent} #{element[:class]}", :id => element[:id],
              :disabled => !(@role.abilities.include?(privilege.to_sym) || !disabled) })
    end
    
    def style(dom)
      case dom
      when "check_box"
        "checkbox"
      when "radio_button"
        "radio"
      else
        ""
      end
    end
end      
