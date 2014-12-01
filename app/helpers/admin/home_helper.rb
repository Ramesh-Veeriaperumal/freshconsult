 module Admin::HomeHelper
  
  ######### Admin Items ########

  def admin_items
    @admin_items ||= {
      :email                           =>   {
        :url                           =>   "/admin/email_configs",
        :privilege                     =>   privilege?(:manage_email_settings)
      },
      :freshchat                       =>   {
        :url                           =>   "/admin/chat_widgets",
        :pjax                          =>   true,
        :privilege                     =>   privilege?(:admin_tasks) && current_account.features?(:chat)
      },
      :freshfone                       =>   {
        :url                           =>   "/admin/freshfone",
        :privilege                     =>   privilege?(:admin_tasks)
      },
      :"twitter"                       =>   {
        :url                           =>   "/admin/social/streams",
        :privilege                     =>   feature?(:twitter) && privilege?(:admin_tasks)
      },
      :"facebook-setting"              =>   {
        :url                           =>   "/social/facebook",
        :privilege                     =>   current_account.features?(:facebook) && privilege?(:admin_tasks)
      },
      :feedback                        =>   {
        :url                           =>   "/admin/widget_config",
        :privilege                     =>   privilege?(:admin_tasks)
      },
      :mobihelp                        =>   {
        :url                           =>   "/admin/mobihelp/apps",
        :privilege                     =>   privilege?(:admin_tasks)
      },
      :rebranding                      =>   {
        :url                           =>   "/account/edit",
        :privilege                     =>   privilege?(:admin_tasks)
      },
      :"ticket-fields"                 =>   {
        :url                           =>   "/ticket_fields",
        :privilege                     =>   privilege?(:admin_tasks)
      },
      :"contact-fields"                 =>   {
        :url                           =>   "/admin/contact_fields",
        :privilege                     =>   (!Rails.env.production?) && privilege?(:admin_tasks)
      },
      :"customer-portal"               =>   {
        :url                           =>   "/admin/portal",
        :privilege                     =>   privilege?(:admin_tasks)
      },
      :agent                           =>   {
        :url                           =>   "/agents",
        :privilege                     =>   privilege?(:manage_users)
      },
      :group                           =>   {
        :url                           =>   "/groups",
        :privilege                     =>   privilege?(:admin_tasks)
      },
      :role                            =>   {
        :url                           =>   "/admin/roles",
        :privilege                     =>   feature?(:custom_roles) && privilege?(:admin_tasks)
      },
      :security                        =>   {
        :url                           =>   "/admin/security",
        :privilege                     =>   privilege?(:admin_tasks)
      },
      :sla                             =>   {
        :url                           =>   "/helpdesk/sla_policies",
        :privilege                     =>   privilege?(:admin_tasks)
      },
      :"business-hours"                =>   {
        :url                           =>   "/admin/business_calendars",
        :privilege                     =>   feature?(:business_hours) && privilege?(:admin_tasks)
      },
      :"multi-product"                 =>   {
        :url                           =>   "/admin/products",
        :privilege                     =>   feature?(:multi_product) && privilege?(:admin_tasks)
      },    
      :tags                            =>   {
        :url                           =>   "/helpdesk/tags",
        :privilege                     =>   privilege?(:admin_tasks)
      },
      :dispatcher                      =>   {
        :url                           =>   "/admin/va_rules",
        :privilege                     =>   privilege?(:manage_dispatch_rules)
      },
      :supervisor                      =>   {
        :url                           =>   "/admin/supervisor_rules",
        :privilege                     =>   privilege?(:manage_supervisor_rules)
      },
      :observer                        =>   {
        :url                           =>   "/admin/observer_rules",
        :privilege                     =>   privilege?(:manage_dispatch_rules)
      },
      :scenario                        =>   {
        :url                           =>   "/admin/automations",
        :privilege                     =>   feature?(:scenario_automations) && privilege?(:manage_scenario_automation_rules)
      },
      :"email-notifications"           =>   {
        :url                           =>   "/admin/email_notifications",
        :privilege                     =>   privilege?(:manage_email_settings)
      },
      :"canned-response"               =>   {
        :url                           =>   "/admin/canned_responses/folders",
        :privilege                     =>   privilege?(:manage_canned_responses)
      },
      :"survey-settings"               =>   {
        :url                           =>   "/admin/surveys",
        :privilege                     =>   current_account.features?(:surveys) && privilege?(:admin_tasks)
      },
      :"gamification-settings"         =>   {
        :url                           =>   "/admin/gamification",
        :privilege                     =>   current_account.features?(:gamification) && privilege?(:admin_tasks)
      },
      :"email_commands_setting"        =>   {
        :url                           =>   "/admin/email_commands_settings",
        :privilege                     =>   privilege?(:manage_email_settings)
      },
      :integrations                    =>   {
        :url                           =>   "/integrations/applications",
        :privilege                     =>   privilege?(:admin_tasks)
      },
      :account                         =>   {
        :url                           =>   "/account",
        :privilege                     =>   privilege?(:manage_account)
      },
      :billing                         =>   {
        :url                           =>   "/subscription",
        :privilege                     =>   privilege?(:manage_account)
      },
      :import                          =>   {
        :url                           =>   "/admin/zen_import",
        :privilege                     =>   privilege?(:manage_account)
      },
      :day_pass                        =>   {
        :url                           =>   "/admin/day_passes",
        :privilege                     =>   privilege?(:manage_account)
      },
      :multiple_mailboxes              =>   {
        :privilege                     =>   feature?(:multiple_emails)
      },
      :layout_customization            =>   {
        :url                           =>   "/admin/portal/#{current_account.main_portal.id}/template#layout",
        :privilege                     =>   feature?(:layout_customization)
      },
      :stylesheet_customization        =>   {
        :url                           =>   "/admin/portal/#{current_account.main_portal.id}/template#custom_css",
        :privilege                     =>   feature?(:css_customization)
      },
      :custom_domain_name              =>   {
        :privilege                     =>   feature?(:custom_domain)
      },
      :automatic_ticket_assignment     =>   {
        :privilege                     =>   feature?(:round_robin)
      },
      :set_businesshour_group          =>   {
        :privilege                     =>   feature?(:multiple_business_hours)
      },
      :create_new_sla                  =>   {
        :url                           =>   "/helpdesk/sla_policies/new",
        :privilege                     =>   feature?(:customer_slas)
      },
      :cancel_service                  =>   {
        :url                           =>   "/account/cancel"
      },
      :add_new_agent                   =>   {
        :url                           =>   "/agents/new"
      },
      :add_new_group                   =>   {
        :url                           =>   "/groups/new"
      },
      :add_new_agent_role              =>   {
        :url                           =>   "/admin/roles/new"
      },
      :forum_moderation                =>   {
        :privilege                     =>   feature?(:forums)
      },
      :trusted_ip                      =>   {
        :privilege                     =>    current_account.features?(:whitelisted_ips)
      },
      :custom_mailbox                  =>   {
        :privilege                     =>    current_account.features?(:mailbox)
      }
    }
  end

  ######### Admin groups & Associated admin items Constant ########

    ADMIN_GROUP = {
      :"support-channels"       =>    ["email", "freshchat", "freshfone", "twitter", "facebook-setting", "feedback", "mobihelp"],
      :"general-settings"       =>    ["rebranding", "ticket-fields", "contact-fields", "customer-portal", "agent", "group", "role", "security", "sla", 
                                          "business-hours", "multi-product", "tags"],
      :"helpdesk-productivity"  =>    ["dispatcher", "supervisor", "observer", "scenario", "email-notifications", "canned-response", 
                                          "survey-settings", "gamification-settings", "email_commands_setting", "integrations"],
      :"account-settings"       =>    ["account", "billing", "import", "day_pass"]
    }

  ######### keywords Constant ########
    
    ####### Keywords HASH Structure ###################

    #### Each :keyword will used as a key of its i18n content ####

    # :admin_item (sym)       =>    {
    #   :open_keywords        =>    [array of keywords (sym)],
    # In case of spl (URL or Privilege) need to assign, the data will get fetch from @admin_item
    #   :closed_keywords      =>    [array of keywords (sym)]
    # }

    ##################################################

    ADMIN_KEYWORDS = {
      :email                      =>      {
          :open_keywords          =>      [:configure_support_email, :Personalized_email_replies, :remove_ticket_id, :reply_to_email],
          :closed_keywords        =>      [:multiple_mailboxes,:custom_mailbox]
      },
      :freshchat                  =>      {
          :open_keywords          =>      [:chat_integration]
      },
      :freshfone                  =>      {
          :open_keywords          =>      [:phone_integration]
      },
      :feedback                   =>      {
          :open_keywords          =>      [:customize_feedback_widget, :embedded_widget, :popup_widget]
      },
      :rebranding                 =>      {
          :open_keywords          =>      [:set_time_zone, :set_helpdesk_language, :set_portal_url, :set_ticket_id, 
                                              :set_portal_name, :supported_languages, :portal_customization],
          :closed_keywords        =>      [:layout_customization, :stylesheet_customization, :custom_domain_name]
      },
      :"ticket-fields"            =>      {
          :open_keywords          =>      [:customize_new_ticket_form]
      },
      :"contact-fields"            =>      {
          :open_keywords          =>      [:customize_new_contact_form]
      },
      :"customer-portal"          =>      {
          :open_keywords          =>      [:signin_using_google, :signin_using_facebook, :signin_using_twitter, :suggestion_solutions],
          :closed_keywords        =>      [:forum_moderation]
      },
      :"agent"                    =>      {
          :open_keywords          =>      [:occasional_agent, :daypass_agent],
          :closed_keywords        =>      [:add_new_agent]
      },
      :"group"                    =>      {
          :closed_keywords        =>      [:automatic_ticket_assignment, :set_businesshour_group, :add_new_group]
      },
      :role                       =>      {
          :open_keywords          =>      [:agent_roles_permissions],
          :closed_keywords        =>      [:add_new_agent_role]
      },
      :security                   =>      {
          :open_keywords          =>      [:ssl_encryption, :single_signon],
          :closed_keywords        =>      [:trusted_ip]
      },
      :sla                        =>      {
          :open_keywords          =>      [:configure_escalation_emails],
          :closed_keywords        =>      [:create_new_sla]
      },
      :"business-hours"           =>      {
          :open_keywords          =>      [:operating_hours, :set_holiday_list, :business_hours_multiple_locations]
      },
      :dispatcher                 =>      {
          :open_keywords          =>      [:ticket_creation_rules]
      },
      :supervisor                 =>      {
          :open_keywords          =>      [:hourly_trigger]
      },
      :observer                   =>      {
          :open_keywords          =>      [:event_based_rules]
      },
      :"survey-settings"          =>      {
          :open_keywords          =>      [:customer_survey]
      },
      :"gamification-settings"    =>      {
          :open_keywords          =>      [:gamification]
      },
      :integrations               =>      {
          :open_keywords          =>      [:list_all_integrations]
      },
      :account                    =>      {
          :open_keywords          =>      [:invoice_emails, :export_data],
          :closed_keywords        =>      [:cancel_service]
      },
      :mobihelp                   =>      { 
          :open_keywords          =>      [:inapp_support , :ios_sdk , :android_sdk]
      }
    }

    KEYWORDS_META = {
      :chat_integration                       =>    [:customize_chat_window, :configure_chat_messages, :customise_chat_window],
      :phone_integration                      =>    [:purchase_support_number, :voice_integration, :ivr, :integrated_phone_support],
      :"twitter"                      =>    [:social],
      :"facebook-setting"                     =>    [:social],
      :stylesheet_customization               =>    [:css_customization, :customisation],
      :custom_domain_name                     =>    [:cname],
      :portal_customization                   =>    [:rebrand_portal, :customisation],
      :automatic_ticket_assignment            =>    [:round_robin_assignment],
      :set_businesshour_group                 =>    [:multiple_business_hours],
      :agent_roles_permissions                =>    [:custom_roles],
      :single_signon                          =>    [:sso],
      :trusted_ip                             =>    [:trusted_ip_meta],
      :business_hours_multiple_locations      =>    [:multiple_business_hours],
      :"multi-product"                        =>    [:multi_brand],
      :ticket_creation_rules                  =>    [:automations, :workflows],
      :hourly_trigger                         =>    [:automations, :workflows],
      :event_based_rules                      =>    [:automations, :workflows],
      :scenario                               =>    [:macros],
      :"email-notifications"                  =>    [:auto_responses],
      :"canned-response"                      =>    [:predefined_responses],
      :"billing"                              =>    [:choose_plan],
      :import                                 =>    [:zendesk_import],
      :"day_pass"                             =>    [:occasional_agent],
      :custom_mailbox                         =>    [:custom_mailbox_meta]
    }

  ######### Constructing Admin Page ########

  def admin_link(items)
    link_item = 
      items.map do |item|
        admin_item = admin_items[item.to_sym]
        next unless admin_item[:privilege]      ## Skip according to the item privilege
          link_content = <<HTML
          <div class="img-outer"><i class = "fsize-36 ficon-#{ item.to_s }" ></i></div>
          <div class="admin-icon-text">#{t(".#{item.to_s}")}</div>
HTML
          if admin_item[:pjax]
            content_tag( :li, pjax_link_to(link_content.html_safe, admin_item[:url].html_safe))
          else
            content_tag( :li, link_to(link_content.html_safe, admin_item[:url].html_safe))
          end
      end

    link_item.to_s.html_safe
  end

  def build_admin_prefpane
    admin_html = 
      ADMIN_GROUP.map do |group_title, items|
        
        url = admin_link(items)
        next if url.blank?
        
        content_tag(:div, 
          content_tag(:h3, "<span>#{t('.'+group_title.to_s)}</span>".html_safe, :class => "title") +
          content_tag(:ul, url, :class => "admin_icons").html_safe, 
              :class => "admin #{ cycle('odd', 'even') } #{group_title} ")
      end

    admin_html.to_s.html_safe
  end

  ###########################################

  ###### Generating Admin UI Keywords #######

  def generate_keywords_hash
    keywords_hash = Hash.new
      ADMIN_GROUP.each do |group_name, items|
        keywords_hash.merge!(keywords(items))
      end
    keywords_hash
  end

  def keywords(admin_items_array)
    kw_items = Hash.new

    admin_items_array.each do |item|

      ## Skip according to the item privilege
      next unless admin_items[item.to_sym][:privilege]

      ## Item URL
      url = admin_items[item.to_sym][:url]
      meta = KEYWORDS_META[item.to_sym]

      kw_items[t(".#{item}")] = 
                    [url, "ficon-#{item}"].concat(meta.blank? ? [] : [meta.map { |e| t("admin.home.keywords.#{e}") }])

      ## if item has keywords
      if( (kw_item = ADMIN_KEYWORDS[item.to_sym]).present? )      
        # Collecting open items
        (kw_item[:open_keywords] || []).each { |kw| 
          kw_items.merge!(collect_keywords(kw, url, item)) 
        }

        # Collecting privilege based meta items
        (kw_item[:closed_keywords] || []).each { |kw|
          kw_items.merge!(collect_keywords(kw, 
            (admin_items[kw][:url] || url), item)) if (admin_items[kw][:privilege].nil? || admin_items[kw][:privilege])
        }
      end

    end

    kw_items
  end

  def collect_keywords(keyword, url, item)
    meta = KEYWORDS_META[keyword.to_sym]
    item_value = [url, "ficon-#{item}"]
    item_value << (meta || []).map { |e| t("admin.home.keywords.#{e}") }

    Hash[t("admin.home.keywords.#{keyword}"), item_value]
  end

  ############################################

end
