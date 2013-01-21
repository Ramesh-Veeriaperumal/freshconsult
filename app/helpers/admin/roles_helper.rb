module Admin::RolesHelper
  
  def refactored
    privilege_hash = [

      # *************************** Tickets **************************

      { :privilege => "-1", :label => "Tickets" , :dom_type => "label", :id => "tickets",
    
        :children => 

          [{ :privilege => "manage_tickets", :label => "Basic agent privileges", :dom_type => "hidden",
            :id => "manage_tickets" },

          { :privilege => "reply_ticket", :label => "Send reply to a ticket", :dom_type => "checkbox",
            :id => "reply_ticket" },

          { :privilege => "forward_ticket", :label => "Forward a conversation", :dom_type => "checkbox",
            :id => "forward_ticket" },

          { :privilege => "-1", :label => "Edit notes", :dom_type => "checkbox",
            :id => "edit_note", :class => "nested permanent_disable",

            :children => 

              [{ :privilege => "edit_note", :label => "Edit everyone's notes", :dom_type => "radio",
                :id => "edit_note_true" },

              { :privilege => "-1", :label => "Edit only their own notes", :dom_type => "radio",
                :id => "edit_note_false", :class => "default" }]

          },

          { :privilege => "edit_conversation", :label => "Edit conversation", :dom_type => "checkbox",
            :id => "edit_conversation"  },
          
          { :privilege => "merge_or_split_ticket", :label => "Merge / split a ticket", :dom_type => "checkbox",
            :id => "merge_or_split_ticket" },
          
          { :privilege => "edit_ticket_properties", :label => "Edit ticket properties", :dom_type => "checkbox",
            :id => "edit_ticket_properties" },
          
          { :privilege => "view_time_entries", :label => "View or edit time entries ", :dom_type => "checkbox",
            :id => "view_time_entries", :class => "nested",

            :children => 
          
              [{ :privilege => "edit_time_entries", :label => "Edit everyone's time entries", :dom_type => "radio",
                :id => "edit_time_entries" },
              
              { :privilege => "-1", :label => "Edit only their time entries", :dom_type => "radio",
                :id => "edit_time_entries", :class => "default" }]

          },

          { :privilege => "delete_ticket", :label => "Delete a ticket", :dom_type => "checkbox",
            :id => "delete_ticket" }]
      },

      # *************************** Solutions **************************  

      { :privilege => "-1", :label => "Solutions" , :dom_type => "label", :id => "solutions",
      
        :children =>

          [{ :privilege => "view_solutions", :label => "View solutions tab", :dom_type => "checkbox",
            :id => "view_solutions", :class => "nested",

            :children => 

              [{ :privilege => "publish_solution", :label => "Publish a solution",
                :dom_type => "checkbox", :id => "publish_solution" },

              { :privilege => "delete_solution", :label => "Delete a solution",
                :dom_type => "checkbox", :id => "delete_solution" },        

              { :privilege => "create_edit_category_folder", :label => "Create / Edit category or forum",
                :dom_type => "checkbox", :id => "create_edit_category_folder" }]
          }]
      },

      # *************************** Forums **************************

      { :privilege => "-1", :label => "Forums" , :dom_type => "label", :id => "forums",
        
        :children =>

          [{ :privilege => "view_forums", :label => "View forums tab",
            :dom_type => "checkbox", :id => "view_forums",
            :class => "nested",

            :children => 

              [{ :privilege => "create_edit_forum_category", :label => "Create / Edit category or forum",
                :dom_type => "checkbox", :id => "create_edit_forum_category" },

                { :privilege => "create_forum_topic", :label => "Create or Edit a forum topic",
                  :dom_type => "checkbox", :id => "create_forum_topic", :class => "nested",

                  :children => 

                    [{ :privilege => "edit_forum_topic", :label => "Edit everyone's forum topic",
                      :dom_type => "radio", :id => "edit_forum_topic_true" },

                    { :privilege => "-1", :label => "Edit only their own forum topic",
                      :dom_type => "radio", :id => "edit_forum_topic_false", :class => "default" }]
                },  

                { :privilege => "delete_forum_topic", :label => "Delete a forum topic", :dom_type => "checkbox",
                  :id => "delete_forum_topic" }]
          }]
      },

      # *************************** Customers **************************

      { :privilege => "-1", :label => "Customers" , :dom_type => "label", :id => "customers",
        
        :children =>

          [{ :privilege => "view_contacts", :label => "View customers tab",
            :dom_type => "checkbox", :id => "view_contacts", :class => "nested",

            :children => 

              [{ :privilege => "add_or_edit_contact", :label => "Create or edit new contact or company",
                :dom_type => "checkbox", :id => "add_or_edit_contact" },

              { :privilege => "delete_contact", :label => "Delete contact or company",
                :dom_type => "checkbox", :id => "delete_contact" }]
          }]
      },

      # *************************** Reports **************************

      { :privilege => "-1", :label => "Reports" , :dom_type => "label", :id => "reports",
        
        :children => 

          [{ :privilege => "view_reports", :label => "View reports tab",
            :dom_type => "checkbox", :id => "view_reports" }]
      },

      # *************************** Admin **************************

      { :privilege => "-1", :label => "Admin", :dom_type => "label", :id => "admin",

        :children =>

          [{ :privilege => "-1", :label => "Not an administrator", :dom_type => "radio",
             :id => "not_administrator", :class => "default"},

            { :privilege => "view_admin", :label => "An operational admin", :dom_type => "radio",
              :id => "operational_admin", :class => "nested",

              :children =>

                [ { :privilege => "manage_users", :label => "Manage Agents", :dom_type => "checkbox",
                    :id => "manage_users" },

                  { :privilege => "manage_canned_responses", :label => "Manage canned responses",
                    :dom_type => "checkbox", :id => "manage_canned_responses" },

                  { :privilege => "manage_dispatch_rules", :label => "Manage Dispatch'r rules",
                    :dom_type => "checkbox", :id => "manage_dispatch_rules" },

                  { :privilege => "manage_supervisor_rules", :label => "Manage Supervisor rules",
                    :dom_type => "checkbox", :id => "manage_supervisor_rules" },

                  { :privilege => "manage_scenario_automation_rules", :label => "Manage Scenario automation rules",
                    :dom_type => "checkbox", :id => "manage_scenario_automation_rules" },

                  { :privilege => "manage_email_settings", :label => "Manage Email Commands",
                    :dom_type => "checkbox", :id => "manage_email_settings" }]

            },

            { :privilege => "super_admin", :label => "A Super admin", :dom_type => "radio",
              :id => "super_admin", :class => "nested",

              :children =>

                [ { :privilege => "view_admin", :label => "Manage Agents", :dom_type => "hidden",
                    :id => "view_admin" },

                  { :privilege => "manage_users", :label => "Manage Agents", :dom_type => "hidden",
                    :id => "manage_users" },

                  { :privilege => "manage_canned_responses", :label => "Manage canned responses",
                    :dom_type => "hidden", :id => "manage_canned_responses" },

                  { :privilege => "manage_dispatch_rules", :label => "Manage Dispatch'r rules",
                    :dom_type => "hidden", :id => "manage_dispatch_rules" },

                  { :privilege => "manage_supervisor_rules", :label => "Manage Supervisor rules",
                    :dom_type => "hidden", :id => "manage_supervisor_rules" },

                  { :privilege => "manage_scenario_automation_rules", :label => "Manage Scenario automation rules",
                    :dom_type => "hidden", :id => "manage_scenario_automation_rules" },

                  { :privilege => "manage_email_settings", :label => "Manage Email Commands",
                    :dom_type => "hidden", :id => "manage_email_settings" },

                  { :privilege => "manage_account", :label => "Include account management",
                    :dom_type => "checkbox", :id => "manage_account" }]

            }]
      }

    ]
  end

  def new_role_form
    @html = ""
    build_roles_form(refactored, "privileges", false)
    @html
  end

  private

    def build_roles_form(array, parent, disabled)
      array.each do |element|
        case element[:dom_type] 
        when "label"
          @html += build_label(element, parent)
        when "checkbox"
          @html += build_checkbox(element, parent, disabled)
        when "radio"
          @html += build_radio(element, parent, disabled)
        when "hidden"
          @html += build_hidden(element, parent, disabled)
        end
        if element.key?(:children)
          @html.safe_concat("<ul class = 'children'>")
          temp = (parent != "privileges")
          build_roles_form(element[:children], element[:id], temp)
          @html.safe_concat("</ul></li>")
        end
      end
      @html
    end

    def build_radio(element, parent, disabled)
      content_tag("li", "<br /><br />" + radio_button_tag("admin_role[privilege_list][#{parent}][]",
        element[:privilege], @role.abilities.include?(element[:privilege].to_sym),
        { :class => "#{parent} #{element[:class]} radio", :id => element[:id],
        :disabled => disabled }) + " #{element[:label].humanize}")
    end

    def build_checkbox(element, parent, disabled)
      content_tag("li", "<br /><br />" + check_box_tag("admin_role[privilege_list][]",
        element[:privilege], @role.abilities.include?(element[:privilege].to_sym),
        { :class => "#{parent} #{element[:class]}", :id => element[:id],
        :disabled => disabled }) + " #{element[:label].humanize}")
    end

    def build_label(element, parent)
      "<br /><br /><h1 class='title #{parent}'>#{element[:label]}</h1>"
    end

    def build_hidden(element, parent, disabled)
      hidden_field_tag("admin_role[privilege_list][]", element[:privilege], 
      { :class => "#{parent} #{element[:class]}", :id => element[:id],
        :disabled => !(@role.abilities.include?(element[:privilege].to_sym) || !disabled) })
    end
end