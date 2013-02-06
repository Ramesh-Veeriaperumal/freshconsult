module Admin::HomeHelper
  
  def admin_link(list_array)
    link_item = list_array.map do |pref|
                  next if !pref[2].nil? && !pref[2]
                    link_content = <<HTML
                    <div class="img-outer"><img width="32px" height="32px" src="/images/spacer.gif" class = "admin-icon-#{ pref[1] }" /></div>
                    <div class="admin-icon-text">#{t(".#{pref[1]}")}</div>
HTML
                    content_tag( :li, link_to( link_content, pref[0] ) )

                end
    link_item
  end
  
  # Defining the Array and constructing the Admin Page links
  # !!! IMPORTANT: 
  #     The name listed below in the Array next to the link is the key value for the Item
  # =>  This key value will be used as the 
  # =>       1. i18n key
  # =>       2. Name of the image that should be placed under the admin-icon folder
  # =>       3. Group title text are also used in admin.scss file as a class name
  
  def admin_pref_links
    admin_links = [

      [ [t(".helpdesk")], [ 
          ['/account/edit',               'rebranding',              privilege?(:admin_tasks) ],
          ['/admin/email_configs',        'email-settings',          privilege?(:manage_email_settings) ],
          ['/admin/email_notifications',  'email-notifications',     privilege?(:manage_email_settings) ],      
          ['/ticket_fields',              'ticket-fields',           privilege?(:admin_tasks) ],
          ['/helpdesk/sla_policies',      'sla',                     privilege?(:admin_tasks) ],  
          ['/admin/business_calendars',   'business-hours',          feature?(:business_hours) && privilege?(:admin_tasks) ],
          ['/admin/products',             'multi-product',           feature?(:multi_product) && privilege?(:admin_tasks) ],
          ['/social/twitters',            'twitter-setting',         feature?(:twitter) && privilege?(:admin_tasks) ],
          ['/social/facebook',            'facebook-setting',        current_account.features?(:facebook) && privilege?(:admin_tasks) ],
          ['/agents',                     'agent',                   privilege?(:manage_users) ],
          ['/groups',                     'group',                   privilege?(:admin_tasks) ],
          ['/admin/day_passes',           'day_pass',                privilege?(:manage_account) ],
          ['/admin/roles',                'roles',                   privilege?(:admin_tasks) ],
      ], "Helpdesk"],
      [ [t(".helpdesk"),t(".productivity")], [ 
          ['/admin/va_rules',             'dispatcher',              privilege?(:manage_dispatch_rules) ],
          ['/admin/supervisor_rules',     'supervisor',              privilege?(:manage_supervisor_rules) ],
          ['/admin/automations',          'scenario',                feature?(:scenario_automations) && privilege?(:manage_scenario_automation_rules) ],
          ['/admin/email_commands_settings', 'email_commands_setting', privilege?(:manage_email_settings) ], 
          ['/integrations/applications',  'integrations',            privilege?(:admin_tasks) ],
          ['/admin/canned_responses/folders',     'canned-response', privilege?(:manage_canned_responses) ],
          ['/admin/surveys',              'survey-settings',         current_account.features?(:surveys) && privilege?(:admin_tasks) ],
          ['/admin/gamification',         'gamification-settings',   current_account.features?(:gamification) && privilege?(:admin_tasks) ]
      ], "HelpdeskProductivity"],
      [ [t(".customer"),t(".portal")], [        
          ['/admin/security',             'security',                privilege?(:admin_tasks) ],
          ['/admin/portal',               'customer-portal',         privilege?(:admin_tasks) ],
          ['/admin/widget_config',        'feedback',                privilege?(:admin_tasks) ],
      ], "CustomerPortal"],
      
      [ [t(".account")], [
          ['/account',                    'account-settings',        privilege?(:manage_account) ],
          ['/subscription',               'billing',                 privilege?(:manage_account) ],
          ['/admin/zen_import',           'import',                  privilege?(:manage_account) ],
      ], "Account"]
    ]
 
    admin_html = 
      admin_links.map do |group|
        links = admin_link(group[1])
        unless links.compact.blank?
          content_tag( :div, 
              content_tag(:h3, "<span>#{group[0][0]} #{group[0][1]}</span>", :class => "title") +
              content_tag(:ul, links, :class => "admin_icons"),
              :class => "admin #{ cycle('odd', 'even') } #{group[2]} ") 
        end
      end
    
    admin_html
  end
end
