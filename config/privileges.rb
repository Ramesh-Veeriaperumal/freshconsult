Authority::Authorization::PrivilegeList.build do
 
  # *************** TICKETS **********************

  manage_tickets do
    resource :"helpdesk/dashboard"
    resource :"helpdesk/quest"
    resource :"helpdesk/leaderboard"
    resource :"helpdesk/note", :only => [:index]
    resource :user, :only => [:delete_avatar, :block]
    resource :"helpdesk/reminder"
    resource :"helpdesk/authorization"
		resource :"helpdesk/ticket", :only => [:show, :new, :create, :show, :index, :user_tickets, :empty_trash, :empty_spam,
                      :user_ticket, :search_tweets, :custom_search, :export_csv, :latest_ticket_count, :add_requester, :view_ticket,
                      :spam, :unspam, :execute_scenario, :pick_tickets,
                      :get_ca_response_content, :merge_with_this_request, :print, :latest_note,
                      :clear_draft, :save_draft, :prevnext, :component, :custom_search, :configure_export,
                      :quick_assign, :canned_reponse, :full_paginate, :custom_view_save,
                      :filter_options, :activities, :status]
    resource :"helpdesk/subscription"
 		resource :"helpdesk/tag_use"
    resource :"helpdesk/tag"
    resource :"mobile/ticket"
    resource :"social/twitter_handle",
       :only => [:create_twicket, :feed, :user_following, :tweet_exists, :send_tweet, :twitter_search]

    resource :"integrations/integrated_resource"
    resource :"integrations/jira_issue"
    resource :"integrations/logmein"
    resource :"integrations/oauth_util"
    resource :"integrations/salesforce" 

    resource :"helpdesk/conversation", :only => [:note]
    resource :"helpdesk/canned_response"
    resource :"helpdesk/ca_folder"
    resource :agent, :only => [:toggle_availability]
    resource :"search/home", :only => [:index, :suggest]
    resource :search, :only => [:index, :suggest, :content]
	end

  reply_ticket do
    resource :"helpdesk/ticket", :only => [:reply_to_conv]
    resource :"helpdesk/conversation", :only => [:reply, :twitter, :facebook]
    resource :"social/twitter_handle", :only => [:send_tweet]
    # In bulk actions you can reply even if you do not have edit_ticket_properties
    resource :"helpdesk/ticket", :only => [:update_multiple_tickets]
    resource :"helpdesk/bulk_ticket_action"
  end

  forward_ticket do
    resource :"helpdesk/ticket", :only => [:forward_conv]
    resource :"helpdesk/conversation", :only => [:forward]
  end

  merge_or_split_ticket do
    resource :"helpdesk/merge_ticket"
    resource :"helpdesk/ticket", :only => [:split_the_ticket]
  end

  edit_ticket_properties do
    resource :"helpdesk/ticket", :only => [:edit, :update, :update_ticket_properties, :assign_to_agent, :assign, :close,
                                   :close_multiple, :update_multiple_tickets, :change_due_by]
    resource :"helpdesk/bulk_ticket_action"
    resource :"helpdesk/common", :only => [:group_agents]                                  
  end

  edit_conversation do
    resource :"helpdesk/note", :only => [:destroy, :restore]
  end

  edit_note do
    resource :"helpdesk/note", :only => [:edit, :update], :owned_by => { :scoper => :notes }
  end

  view_time_entries do
    resource :"helpdesk/time_sheet", :only => [:index, :new, :create, :toggle_timer]
  end

  edit_time_entries do
    resource :"helpdesk/time_sheet", :only => [:edit, :update, :destroy], :owned_by => 
                                            { :scoper => :time_sheets }
  end

  delete_ticket do
    resource :"helpdesk/ticket", :only => [:destroy, :restore, :delete_forever, :empty_trash]
  end

  # ************** SOLUTIONS **************************

  view_solutions do
    resource :"solution/category", :only => [:index, :show]
    resource :"solution/folder", :only => [:index, :show]
    resource :"solution/article", :only => [:index, :show]
    resource :"search/home", :only => [:solutions]
    resource :search, :only => [:solutions]
  end

  publish_solution do
    resource :"solution/article", :only => [:new, :create, :edit, :update, :delete_tag, :reorder]
    resource :"solution/tag_use"
    resource :uploaded_image, :only => [:create]
  end

  delete_solution do
    resource :"solution/article", :only => [:destroy], :owned_by =>
                                  { :scoper => :solution_articles }
  end

  manage_solutions do
    resource :"solution/category", :only => [:new, :create, :edit, :update, :destroy, :reorder]
    resource :"solution/folder", :only => [:new, :create, :edit, :update, :destroy, :reorder]
  end

  # ************** FORUMS **************************

	view_forums do
    resource :forum_category, :only => [:index, :show]
    resource :forum, :only => [:index, :show]
    resource :topic, :only => [:index, :show, :vote, :destroy_vote, :users_voted]
    resource :post, :only => [:index, :show, :create, :toggle_answer, :monitored]
    # review code for monitorship?
    resource :monitorship
    resource :"search/home", :only => [:topics]
    resource :search, :only => [:topics]
  end

  # create_edit_forum_category
  manage_forums do
    resource :forum_category, :only => [:new, :create, :edit, :update, :destroy, :reorder]
    resource :forum, :only => [:new, :create, :edit, :update, :destroy, :reorder]
  end

  # create_forum_topic
  create_topic do
    resource :topic, :only => [:new, :create ]
  end

  # edit_forum_topic
  edit_topic do
    resource :topic, :only => [:edit, :update, :update_lock, 
          :update_stamp, :remove_stamp], :owned_by => { :scoper => :topics }
    resource :post, :only => [:destroy, :edit, :update], :owned_by => { :scoper => :posts }
  end

  # delete_forum_topic
  delete_topic do
    resource :topic, :only => [:destroy], :owned_by => { :scoper => :topics }
  end

  # ************** CONTACTS **************************

	view_contacts do
	 resource :contact, :only => [:index, :show, :hover_card, :configure_export, :export_csv]
	 resource :customer, :only => [:index, :show]
    resource :agent, :only => [:show]
    resource :user, :only => [:index, :show]
	end

  # add_or_edit_contact
  manage_contacts do
    resource :contact, :only => [:new, :create, :autocomplete, :quick_customer,
               :contact_email, :edit, :update]
    resource :customer, :only => [:new, :create, :edit, :update, :quick]
    resource :contact_import
    # is this the correct place to put this ?
    resource :user, :only => [:new, :create, :edit, :update]
  end

  delete_contact do
    resource :contact, :only => [:destroy, :restore, :unblock]
    resource :customer, :only => [:destroy]
    # is this the correct place to put this ?
    resource :user, :only => [:destroy]
  end

  # ************** REPORTS **************************

	view_reports do
      resource :report
      resource :"reports/agent_glance_report"
      resource :"reports/agents_analysi"
      resource :"reports/agents_comparison"
      resource :"reports/customer_glance_report"
      resource :"reports/customer_report"
      resource :"reports/customers_analysi"
      resource :"reports/gamification_report"      
      resource :"reports/group_glance_report"
      resource :"reports/groups_analysi"
      resource :"reports/groups_comparison"
      resource :"reports/helpdesk_glance_report"
      resource :"reports/helpdesk_load_analysi"
      resource :"reports/helpdesk_performance_analysi"
      resource :"reports/helpdesk_report"
      resource :"reports/survey_report"
   	resource :"reports/timesheet_report"
	end

  # ************** ADMIN **************************

  view_admin do
    resource :"admin/home"
  end

  # ************** Operational Admin ***************

  manage_users do
    # NOTE: The agent show action is also allowed in view_contacts privilege
    resource :agent, :only => [:new, :create, :edit, :update, :index, :destroy, :show, :delete_avatar,
                      :restore, :convert_to_user, :reset_password, :create_multiple_items, :convert_to_contact]
    resource :contact, :only => [:make_agent, :make_occasional_agent]
    resource :activation, :only => [:send_invite]
    resource :user, :only => [:assume_identity]
  end

  manage_canned_responses do
    resource :"admin/canned_responses/folder"
    resource :"admin/canned_responses/response"
  end

  manage_dispatch_rules do
    resource :"admin/va_rule"
  end

  manage_supervisor_rules do
    resource :"admin/supervisor_rule"
  end

  manage_scenario_automation_rules do
    resource :"admin/automation"
  end

  manage_email_settings do
    resource :"admin/email_config"
    resource :"admin/email_notification"
    resource :"admin/email_commands_setting"
    resource :"admin/account_additional_setting"
  end

  # **************** super admin *******************
  # super_admin
  admin_tasks do
    resource :"admin/business_calendar"
    resource :"admin/supervisor_rule"
    resource :"social/twitter_handle", :only => [:index, :edit, :update, :destroy, :signin, :authdone, :search]
    resource :"social/facebook_page"
    resource :"admin/survey"
    resource :group
    resource :ticket_field
    resource :"admin/role"
    resource :"admin/product"
    resource :"admin/portal"
    resource :"admin/security"
    resource :"admin/home"
    resource :"admin/widget_config"
    resource :"integrations/application"
    resource :"integrations/installed_application"
    resource :"integrations/google_account"     
    resource :"admin/gamification"
    resource :"admin/quest"
    resource :"helpdesk/sla_policy"
    resource :account, :only => [:update, :edit, :delete_logo, :delete_fav]
    resource :"admin/template"
    resource :"admin/page"
    resource :"support/preview"
  end

  manage_account do
    resource :account, :only => [:show, :cancel]
    resource :account_configuration
    resource :"admin/data_export"
    resource :subscription # plans and billing
    resource :"admin/zen_import"
    # new item day passes && getting started
    resource :"admin/day_pass"
    resource :"admin/getting_started"
  end

  client_manager do
  end

  # Authority::Authorization::PrivilegeList.privileges.each { |privilege| puts privilege}

end