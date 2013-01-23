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
          ['/account/edit',               'rebranding',              privilege?(:manage_account)],
          ['/admin/email_configs',        'email-settings',  privilege?(:manage_email_settings)],
          ['/admin/email_notifications',  'email-notifications',privilege?(:manage_email_settings)],      
          ['/ticket_fields',              'ticket-fields', privilege?(:super_admin)],
          ['/helpdesk/sla_policies',      'sla', privilege?(:super_admin)],  
          ['/admin/business_calendars',   'business-hours', feature?(:business_hours) && privilege?(:super_admin)],
          ['/admin/products',             'multi-product',    feature?(:multi_product) && privilege?(:super_admin)],
          ['/social/twitters',            'twitter-setting',feature?(:twitter) && privilege?(:super_admin)],
          ['/social/facebook',            'facebook-setting', current_account.features?(:facebook) && privilege?(:super_admin)],
          ['/agents',                     'agent', privilege?(:manage_users)],
          ['/groups',                     'group', privilege?(:super_admin)],
          ['/admin/day_passes',           'day_pass', privilege?(:manage_account)],
          ['/admin/roles',                'roles',    privilege?(:super_admin)],
      ], "Helpdesk"],
      [ [t(".helpdesk"),t(".productivity")], [ 
          ['/admin/va_rules',             'dispatcher', privilege?(:manage_dispatch_rules)],
          ['/admin/supervisor_rules',     'supervisor', privilege?(:manage_supervisor_rules)              ],
          ['/admin/automations',          'scenario',   feature?(:scenario_automations) && privilege?(:manage_scenario_automation_rules) ],
          ['/admin/email_commands_settings', 'email_commands_setting', privilege?(:manage_email_settings)], 
          ['/integrations/applications',  'integrations', privilege?(:super_admin)],
          ['/admin/canned_responses/folders',     'canned-response', privilege?(:manage_canned_responses) ],
          ['/admin/surveys',              'survey-settings', current_account.features?(:surveys) && privilege?(:super_admin)      ],
          ['/admin/gamification',         'gamification-settings', current_account.features?(:gamification) && privilege?(:super_admin)      ]
      ], "HelpdeskProductivity"],
      [ [t(".customer"),t(".portal")], [        
          ['/admin/security',             'security', privilege?(:super_admin)   ],
          ['/admin/portal',               'customer-portal', privilege?(:super_admin)         ],
          ['/admin/widget_config',        'feedback', privilege?(:super_admin)                ],
      ], "CustomerPortal"],
      
      [ [t(".account")], [
          ['/account',                    'account-settings', privilege?(:manage_account) ],
          ['/subscription',               'billing', privilege?(:manage_account) ],
          ['/admin/zen_import',           'import', privilege?(:manage_account)                  ],
      ], "Account"]
    ]
 
    admin_html = 
      admin_links.map do |group|
        content_tag( :div, 
                        content_tag(:h3, "<span>#{group[0][0]} #{group[0][1]}</span>", :class => "title") +
                        content_tag(:ul, admin_link(group[1]), :class => "admin_icons"),
                        :class => "admin #{ cycle('odd', 'even') } #{group[2]} ")
      end

    admin_html
  end
end
