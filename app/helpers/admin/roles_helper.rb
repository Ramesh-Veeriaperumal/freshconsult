module Admin::RolesHelper

  def role_sections
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
             { :dom_type => "check_box", :id => "edit_ticket_properties", :class => "nested",
               :children => 
               [{ :dom_type => "check_box", :id => "edit_ticket_skill", :not_display => !current_account.skill_based_round_robin_enabled? }]
              },
             { :dom_type => "check_box", :id => "view_time_entries", :class => "nested",
               :children =>

                [{ :dom_type => "radio_button", :id => "edit_time_entries" },
                 { :dom_type => "radio_button", :id => "edit_time_entries_false",
                   :privilege => "0", :class => "default" }]
             },
             { :dom_type => "check_box", :id => "delete_ticket" },
             { :dom_type => "check_box", :id => "export_tickets" }]
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

         # *************************** Bots *******************************

         { dom_type: "label", id: "bots", not_display: !current_account.support_bot_enabled?,
           children: 

              [{ dom_type: "check_box", id: "view_bots", not_display: !current_account.support_bot_enabled? }]

         },

         # *************************** Customers **************************

         { :dom_type => "label", :id => "customers",
           :children =>

             [{ :dom_type => "check_box", :id => "view_contacts", :class => "nested",
                :children =>

                 [{ :dom_type => "check_box", :id => "manage_contacts" },
                  { :dom_type => "check_box", :id => "delete_contact" },
                  {:dom_type => "check_box", :id => "export_customers"}]
                
             }]
             
         },

         # *************************** Reports **************************

         { :dom_type => "label", :id => "analytics", :children =>

             [{ :dom_type => "check_box", :id => "view_reports", :class => "nested",
                :children => 
                
                [{ :dom_type => "check_box", :id => "export_reports"},
                 { :dom_type => "check_box", :id => "manage_dashboard"}]
                
             }]
             
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
                    { :dom_type => "check_box", :id => "manage_availability" },
                    { :dom_type => "check_box", :id => "manage_skills", :not_display => !current_account.skill_based_round_robin_enabled? },
                    { :dom_type => "check_box", :id => "manage_tags" },
                    { :dom_type => "check_box", :id => "manage_canned_responses" },
                    { :dom_type => "check_box", :id => "manage_dispatch_rules" },
                    { :dom_type => "check_box", :id => "manage_supervisor_rules" },
                    { :dom_type => "check_box", :id => "manage_scenario_automation_rules" },
                    { :dom_type => "check_box", :id => "manage_email_settings" },
                    { :dom_type => "check_box", :id => "manage_ticket_list_views" },
                    { :dom_type => "check_box", :id => "manage_ticket_templates" },
                    { :dom_type => "check_box", :id => "manage_bots", not_display: !current_account.support_bot_enabled? }
                    ]
               },

               { :dom_type => "radio_button", :id => "admin_tasks", :class => "nested",
                 :children =>

                   [{ :dom_type => "hidden_field", :id => "view_admin" },
                    { :dom_type => "hidden_field", :id => "manage_users" },
                    { :dom_type => "hidden_field", :id => "manage_availability" },
                    { :dom_type => "hidden_field", :id => "manage_skills", :not_display => !current_account.skill_based_round_robin_enabled? },
                    { :dom_type => "hidden_field", :id => "manage_canned_responses" },
                    { :dom_type => "hidden_field", :id => "manage_dispatch_rules" },
                    { :dom_type => "hidden_field", :id => "manage_supervisor_rules" },
                    { :dom_type => "hidden_field", :id => "manage_scenario_automation_rules" },
                    { :dom_type => "hidden_field", :id => "manage_email_settings" },
                    { :dom_type => "hidden_field", :id => "manage_ticket_list_views" },
                    { :dom_type => "hidden_field", :id => "manage_ticket_templates" },
                    { :dom_type => "hidden_field", :id => "manage_bots", not_display: !current_account.support_bot_enabled? },
                    { :dom_type => "check_box",    :id => "manage_account" }]

               }]
         },
         
          # *************************** General **************************

         { :dom_type => "label", :id => "general", 
            :children =>
              [{ :dom_type => "check_box", :id => "create_tags"}]
         },
      ]
  end

  def build_role_form
    form = ""
    role_sections.each do |section|
      unless section[:not_display]
       form +=  content_tag( :div, {:class => "row-fluid margin-bottom", :id => section[:id] }) do
          content_tag( :div, content_tag( :p, t('admin.roles.privilege.'+ section[:id]).html_safe, :class => "lead-sub"), :class => "span2") +
          content_tag( :div, :class => "span10 role-section") do
            value = label(:agent, :signature_html, "<b>#{t('admin.roles.agent_can')}</b>".html_safe)
            if section[:children]
              if section[:children].last[:children] and section[:children].last[:children].last[:id] == "manage_account" and !current_user.privilege?(:manage_account)
                section[:children].last[:children].last.merge!(:class => "permanent_disable")
              end
              value += process_children(section[:children], section[:id], false)
            end
            value
          end
        end
      end
    end
    form.html_safe
  end


  def process_children(children, parent, disabled)
    content_tag(:ul, :class => "nested-ul") do
      children.map do |child| 
        unless child[:not_display] 
          content_tag(:li) do
            element =
              content_tag(:label, :class => "#{child[:dom_type]} #{style(child[:dom_type])}") do
                case child[:dom_type]
                when "check_box", "radio_button"
                  build_element(child, parent, disabled)
                when "hidden_field"
                  build_hidden(child, parent, disabled)
                end
              end # label
              if child[:children]
                element += process_children(child[:children], child[:id], true)
              end
              element.html_safe
          end.to_s.html_safe # li
        end.to_s.html_safe #unless
      end.to_s.html_safe # map
    end.to_s.html_safe #ul
  end

  private

    def build_element(element, parent, disabled)
      privilege = element[:privilege] || element[:id]
      name = (element[:dom_type] == "radio_button") ? "role[privilege_list][#{parent}][]" : "role[privilege_list][]"

      html = eval "#{element[:dom_type]}_tag('#{name}', '#{privilege}',
      #{@role.abilities.include?(privilege.to_sym)}, { :class => '#{parent} #{element[:class]}',
      :id => '#{element[:id]}', :disabled => #{disabled}})"
      html = (html + t('admin.roles.privilege.'+ element[:id])).html_safe
    end

    def build_hidden(element, parent, disabled)
      privilege = element[:privilege] || element[:id]
      hidden_field_tag("role[privilege_list][]", privilege,
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
