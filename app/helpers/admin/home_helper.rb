module Admin::HomeHelper
  
  def admin_link(list_array)
    link_item = list_array.map do |pref|
                  next if !pref[2].nil? && !pref[2]
                    link_content = image_tag( "/images/spacer.gif", :class => "admin-icon-#{ pref[1] }" ) +
                                   content_tag( :div, t(".#{pref[1]}") )
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
  
  def admin_pref_links
    admin_links = [
                    [ t(".everything_helpdesk"), [
                                    ['/account/edit',               'rebranding'              ],
                                    ['/admin/email_configs',        'email-settings'          ],
                                    ['/admin/email_notifications',  'email-notifications'     ],
                                    ['/ticket_fields',              'ticket-fields'           ],
                                    ['/helpdesk/sla_policies',      'sla'                     ],
                                    ['/admin/business_calendars',   'business-hours',   feature?(:business_hours)        ],
                                    ['/admin/va_rules',             'dispatcher'              ],
                                    ['/admin/automations',          'scenario',         feature?(:scenario_automations)  ],
                                    ['/admin/products',             'multi-product',    feature?(:multi_product)  ] ,
                                    ['/admin/twitters',     'twitter-setting'         ]
                    ]],
                    [ t(".everything_else"), [
                                    ['/account',                    'account-settings'  , current_user.account_admin?      ],
                                    ['/admin/portal',               'customer-portal'         ],
                                    ['/admin/security',             'remote-authentication'   ],
                                    ['/admin/zip_readers',          'import'                  ],
                                    ['/admin/widget_config',        'feedback'                ],
                                    ['/agents',                     'agent'                   ],
                                    ['/groups',                     'group'                   ]
                    ]]

                    # [ "People & Roles", [
                    #                 ['/agents',   'agent' ],
                    #                 ['/groups',   'group' ]
                    # ]],
                    # [ "Account", [
                    #                 ['/account',            'account-settings' ],
                    #                 ['/admin/security',     'remote-authentication' ],
                    #                 ['/admin/zip_readers',  'import' ]
                    # ]]
                  ]

    admin_html = 
      admin_links.map do |group|
        content_tag( :div, 
                        content_tag(:h3, group[0], :class => "title") +
                        content_tag(:ul, admin_link(group[1]), :class => "admin_icons"),
                        :class => "admin #{ cycle('odd', 'even') }" )
      end

    admin_html
  end
end
