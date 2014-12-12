Authority::Authorization::PrivilegeList.build do
 
  # *************** TICKETS **********************

  manage_tickets do
    resource :"helpdesk/dashboard", :only => [:index, :activity_list,:latest_activities,:latest_summary,:sales_manager]
    resource :"helpdesk/quest"
    resource :"helpdesk/leaderboard"
    resource :"helpdesk/note", :only => [:index, :agents_autocomplete]
    resource :user, :only => [:delete_avatar, :block, :me]
    resource :"helpdesk/reminder"
    resource :"helpdesk/authorization"
    resource :"search/autocomplete", :only => [:requesters, :agents, :companies, :tags]
		resource :"helpdesk/ticket", :only => [:show, :new, :create, :show, :index, :user_tickets, :empty_trash, :empty_spam,
                      :user_ticket, :search_tweets, :custom_search, :export_csv, :latest_ticket_count, :add_requester, :view_ticket,
                      :spam, :unspam, :execute_scenario, :pick_tickets,
                      :get_ca_response_content, :merge_with_this_request, :print, :latest_note,
                      :clear_draft, :save_draft, :prevnext, :component, :custom_search, :configure_export,
                      :quick_assign, :canned_reponse, :full_paginate, :custom_view_save,
                      :filter_options, :activities, :status, :get_top_view, :recent_tickets, :old_tickets, :summary]
    resource :"helpdesk/subscription"
 		resource :"helpdesk/tag_use"
    resource :"helpdesk/tag"
    resource :"helpdesk/visitor"
    resource :"helpdesk/autocomplete"
    resource :"helpdesk/chat"
    resource :"mobile/ticket"
    resource :"mobile/automation"
	resource :"mobile/notification"
	resource :"mobile/freshfone"
    resource :"mobile/setting"    
    resource :"helpdesk/mobihelp_ticket_extra"
    # Social - Twitter
    resource :"social/twitter_handle",
       :only => [:create_twicket, :feed, :user_following, :tweet_exists, :send_tweet, :twitter_search]
    resource :"social/stream",
       :only => [ :index, :stream_feeds, :show_old, :fetch_new, :interactions]
    resource :"social/twitter",
        :only => [:user_info, :retweets, :twitter_search, :show_old, :fetch_new]
    resource :"health_status"

    resource :"integrations/integrated_resource"
    resource :"integrations/jira_issue"
    resource :"integrations/oauth_util"
    resource :"integrations/salesforce" 
    resource :"integrations/user_credential"
    resource :"integrations/pivotal_tracker"
    resource :"integrations/cti/customer_detail"
    #Freshfone
    resource :"freshfone", :only => [:dashboard_stats, :credit_balance, :create_ticket, :create_note]
    resource :"freshfone/ivr"
    resource :"freshfone/user"
    resource :"freshfone/call", :only => [:caller_data, :inspect_call]
    resource :"freshfone/call_history"
    resource :"freshfone/blacklist_number"
    resource :"freshfone/autocomplete"
    resource :"freshfone/call_transfer", :only => [:initiate, :available_agents]
    resource :"freshfone/device", :only => [:recorded_greeting]
    resource :"freshfone/queue", :only => [:bridge]

    resource :"helpdesk/conversation", :only => [:note, :full_text]
    resource :"helpdesk/canned_response"
    resource :"helpdesk/ca_folder"
    resource :agent, :only => [:toggle_availability, :list]
    resource :"search/home", :only => [:index, :suggest]
    resource :"search/solution", :only => [:related_solutions, :search_solutions]
    resource :"search/ticket", :only => [:index]
    resource :"chat", :only => [:create_ticket, :add_note, :agents, :enable]
    resource :"helpdesk/survey"
    resource :"admin/data_export" , :only => [:download]
    resource :"notification/product_notification", :only => [:index]
    # resource :"helpdesk/common", :only => [:group_agents]

	end

  reply_ticket do
    resource :"helpdesk/ticket", :only => [:reply_to_conv]
    resource :"helpdesk/conversation", :only => [:reply, :twitter, :facebook, :mobihelp]
    resource :"social/twitter_handle", :only => [:send_tweet]
    # In bulk actions you can reply even if you do not have edit_ticket_properties
    resource :"helpdesk/ticket", :only => [:update_multiple_tickets]
    resource :"helpdesk/bulk_ticket_action"
    # Used for API
    resource :"helpdesk/note", :only => [:create]
    resource :"social/twitter",
        :only => [:create_fd_item, :reply, :retweet, :post_tweet, :favorite, :unfavorite, :followers, :follow, :unfollow]
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
  end

  edit_conversation do
    resource :"helpdesk/note", :only => [:destroy, :restore]
  end

  edit_note do
    resource :"helpdesk/note", :only => [:edit, :update], :owned_by => { :scoper => :notes }
  end

  view_time_entries do
    resource :"helpdesk/time_sheet", :only => [:index, :new, :create, :toggle_timer , :show]
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
    resource :"search/solution", :only => [:index]
    resource :"helpdesk/ticket", :only => [:get_solution_detail]
  end

  publish_solution do
    resource :"solution/article", :only => [:new, :create, :edit, :update, :delete_tag, :reorder]
    resource :"solution/tag_use"
    resource :solutions_uploaded_image, :only => [:create]
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
    resource :discussion, :only => [:index, :show, :your_topics, :sidebar, :categories]
    resource :"discussions/forum", :only => [:show]
    resource :"discussions/topic", :only => [:show, :component, :latest_reply, :vote, :destroy_vote]
    resource :forum_category, :only => [:index, :show]
    resource :forum, :only => [:index, :show]
    resource :topic, :only => [:index, :show, :vote, :destroy_vote, :users_voted]
    resource :post, :only => [:index, :show, :create, :toggle_answer, :monitored, :best_answer]
    resource :"discussions/post", :only => [:index, :show, :create, :toggle_answer, :monitored, :best_answer]
    # review code for monitorship?
    resource :"search/home", :only => [:topics]
    resource :"search/forum", :only => [:index]
    resource :"search/merge_topic", :only => [:index]
    resource :forums_uploaded_image, :only => [:create]
  end

  # create_edit_forum_category
  manage_forums do
    resource :forum_category, :only => [:new, :create, :edit, :update, :destroy, :reorder]
    resource :discussion, :only => [:new, :create, :edit, :update, :destroy, :reorder]
    resource :"discussions/forum", :only => [:new, :create, :edit, :update, :destroy, :reorder]
    resource :forum, :only => [:new, :create, :edit, :update, :destroy, :reorder]
  end

  # create_forum_topic
  create_topic do
    resource :"discussions/topic", :only => [:new, :create ]
    resource :topic, :only => [:new, :create ]
    resource :forums_uploaded_image, :only => [:create]
  end

  # edit_forum_topic
  edit_topic do
    resource :"discussions/topic", :only => [:edit, :update, :toggle_lock,
          :update_stamp, :remove_stamp, :merge_topic], :owned_by => { :scoper => :topics }
    resource :topic, :only => [:edit, :update, :update_lock,
          :update_stamp, :remove_stamp], :owned_by => { :scoper => :topics }
    resource :post, :only => [:destroy, :edit, :update], :owned_by => { :scoper => :posts }
    resource :"discussions/post", :only => [:destroy, :edit, :update], :owned_by => { :scoper => :posts }
    resource :"discussions/merge_topic", :owned_by => { :scoper => :topics }
  end

  # delete_forum_topic
  delete_topic do
    resource :"discussions/topic", :only => [:destroy, :destroy_multiple], :owned_by => { :scoper => :topics }
    resource :topic, :only => [:destroy, :destroy_multiple], :owned_by => { :scoper => :topics }
    resource :"discussions/moderation"
  end

  # ************** CONTACTS **************************

	view_contacts do
	 resource :contact, :only => [:index, :show, :hover_card, :hover_card_in_new_tab, :configure_export, :export_csv]
	  resource :customer, :only => [:index, :show] #should deprecate
    resource :company,  :only => [:index, :show]
    resource :agent, :only => [:show]
    resource :user, :only => [:index, :show]
    resource :"search/customer", :only => [:index]
	end

  # add_or_edit_contact
  manage_contacts do
    resource :contact, :only => [:new, :create, :autocomplete, :quick_contact_with_company,
               :create_contact, :update_contact, :update_bg_and_tags, :contact_email, :edit, :update, :verify_email]
    resource :customer, :only => [:new, :create, :edit, :update] #should deprecate
    resource :company,  :only => [:new, :create, :edit, :update, :create_company, :update_company, :quick, :sla_policies]
    resource :"search/autocomplete", :only => [:companies]
    resource :contact_import
    resource :contact_merge
    resource :user_email
    # is this the correct place to put this ?
    resource :user, :only => [:new, :create, :edit, :update]
  end

  delete_contact do
    resource :contact, :only => [:destroy, :restore, :unblock]
    resource :customer, :only => [:destroy] #should deprecate
    resource :company, :only => [:destroy]
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
      resource :"reports/freshfone/summary_report"
      resource :"reports/freshchat/summary_report"
   	resource :"reports/timesheet_report"
    resource :"reports/report_filter"
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
    resource :agent, :only => [:toggle_shortcuts], :owned_by => { :scoper => :agents }
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
    resource :"admin/observer_rule"
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
    resource :"admin/dynamic_notification_template"
    resource :"admin/email_commands_setting"
    resource :"admin/account_additional_setting"
  end

  # **************** super admin *******************
  # super_admin
  admin_tasks do
    resource :"admin/business_calendar"
    resource :"social/twitter_handle", :only => [:index, :edit, :update, :destroy, :signin, :authdone, :search]
    resource :"social/streams"
    resource :"social/welcome"
    resource :"social/facebook_page"
    resource :"social/facebook_tab"
    resource :"admin/survey"
    resource :group
    resource :ticket_field
    resource :"admin/contact_field"
    resource :"admin/company_field"
    resource :"admin/role"
    resource :"admin/product"
    resource :"admin/portal"
    resource :"admin/security"
    resource :"admin/home"
    resource :"admin/widget_config"
    resource :"integrations/application"
    resource :"integrations/installed_application"
    resource :"integrations/google_account"
    resource :"integrations/remote_configuration"
    resource :"admin/freshfone"
    resource :"admin/freshfone/number"
    resource :"admin/gamification"
    resource :"admin/quest"
    resource :"helpdesk/sla_policy"
    resource :account, :only => [:update, :edit, :delete_logo, :delete_favicon]
    resource :"admin/template"
    resource :"admin/page"
    resource :"support/preview"
    resource :"admin/chat_setting"
    resource :"admin/chat_widget"
    resource :"api_webhook", :only => [:create, :destroy]
    resource :"admin/social/stream"
    resource :"admin/social/twitter_stream"
    resource :"admin/social/twitter_handle"
    resource :"admin/mobihelp/app"
    resource :"helpdesk/dashboard",:only => [:agent_status]
  end

  manage_account do
    resource :account, :only => [:show, :cancel]
    resource :account_configuration
    resource :"admin/data_export"
    resource :subscription # plans and billing
    resource :"admin/zen_import"
    # new item day passes && getting started
    resource :"admin/day_pass"
    resource :"admin/freshfone/credit"
    resource :"admin/getting_started"
  end

  client_manager do
  end

  # Authority::Authorization::PrivilegeList.privileges.each { |privilege| puts privilege}

end
