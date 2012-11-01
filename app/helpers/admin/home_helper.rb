module Admin::HomeHelper
  
  def admin_link(list_array)
    link_item = list_array.map do |pref|
                  next if !pref[2].nil? && !pref[2]

                    link_content = <<HTML
                    <div class="img-outer"><img src="/images/spacer.gif" class = "admin-icon-#{ pref[1] }" /></div>
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
          ['/account/edit',               'rebranding'              ],
          ['/admin/email_configs',        'email-settings'          ],
          ['/admin/email_notifications',  'email-notifications'     ],      
          ['/ticket_fields',              'ticket-fields'           ],
          ['/helpdesk/sla_policies',      'sla'                     ],  
          ['/admin/business_calendars',   'business-hours', feature?(:business_hours) ],
          ['/admin/products',             'multi-product',    feature?(:multi_product)  ],
          ['/social/twitters',            'twitter-setting',feature?(:twitter) ],
          ['/social/facebook',            'facebook-setting', current_account.features?(:facebook) ],
          ['/agents',                     'agent'                   ],
          ['/groups',                     'group'                   ],
          ['/admin/day_passes',           'day_pass', current_user.account_admin? ],
      ]],
      [ [t(".helpdesk"),t(".productivity")], [ 
          ['/admin/va_rules',             'dispatcher'              ],
          ['/admin/supervisor_rules',     'supervisor'              ],
          ['/admin/automations',          'scenario',       feature?(:scenario_automations) ],
          ['/admin/email_commands_settings', 'email_commands_setting'], 
          ['/integrations/applications',  'integrations'            ],
          ['/admin/canned_responses',     'canned-response'         ],
          ['/admin/surveys',              'survey-settings', current_account.features?(:surveys)      ],
          ['/admin/gamification',         'gamification-settings', current_account.features?(:gamification)      ]
      ]],
      [ [t(".customer"),t(".portal")], [        
          ['/admin/security',             'security'   ],
          ['/admin/portal',               'customer-portal'         ],
          ['/admin/widget_config',        'feedback'                ],
      ]],
      
      [ [t(".account")], [
          ['/account',                    'account-settings', current_user.account_admin? ],
          ['/subscription',               'billing', current_user.account_admin? ],
          ['/admin/zen_import',           'import'                  ],
      ]]
    ]
 
    admin_html = 
      admin_links.map do |group|
        content_tag( :div, 
                        content_tag(:h3, "<span>#{group[0][0]} #{group[0][1]}</span>", :class => "title") +
                        content_tag(:ul, admin_link(group[1]), :class => "admin_icons"),
                        :class => "admin #{ cycle('odd', 'even') } #{group[0]} ")
      end

    admin_html
  end
end
