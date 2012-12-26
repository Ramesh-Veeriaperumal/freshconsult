Authority::Authorization::PrivilegeList.draw do

  manage_account do
    resource :user, :only => [:change_account_admin]
    resource :"admin/data_export"
    resource :"admin/day_pass"
    resource :account, :only => [:show, :cancel]
    resource :"admin/getting_started"
  end

  manage_users do
    resource :agent, :only => [:new, :create, :edit, :update, :index, :destroy, :delete_avatar,
                      :restore, :convert_to_user, :reset_password, :create_multiple_items]
    resource :contact, :only => [:make_agent]
    resource :activation, :only => [:send_invite]
    resource :user, :only => [:assume_identity]
  end

  manage_tickets do
    resource :"helpdesk/dashboard"
    resource :"helpdesk/quest"
    resource :"helpdesk/leaderboard"
    resource :"helpdesk/note", :only => [:index]
    # Users crud have been moved to contacts, what about delete avatar
    # shouldnt delete avatar be part of profiles controller?
    resource :user, :only => [:delete_avatar, :block]
    resource :"helpdesk/reminder"
    resource :"helpdesk/authorization"
		resource :"helpdesk/ticket", :only => [:show, :new, :create, :show, :index, :user_tickets, :empty_trash, :empty_spam,
                      :user_ticket, :search_tweets, :custom_search, :export_csv, :update_multiple,
                      :update_multiple_tickets, :latest_ticket_count, :add_requester, :view_ticket,
                      :assign, :spam, :unspam, :execute_scenario, :pick_tickets,
                      :get_ca_response_content, :merge_with_this_request, :print, :latest_note,
                      :clear_draft, :save_draft, :prevnext, :component, :custom_search, :configure_export,
                      :quick_assign, :update_ticket_properties, :canned_reponse]
    resource :"helpdesk/subscription"
 		resource :"helpdesk/tag_use"
    resource :"helpdesk/tag"
    # special case
    resource :"mobile/ticket"
 		# There seems to be some some sort of a render error in suggest solutions in tickets page
    resource :"social/twitter_handle", :only => [:create_twicket, :feed, :user_following, :tweet_exists, :send_tweet]

    resource :"integrations/integrated_resource"
    resource :"integrations/jira_issue"
    resource :"integrations/logmein"
    resource :"integrations/oauth_util"
    resource :"integrations/salesforce"
	end

  reply_ticket do
    resource :"helpdesk/ticket", :only => [:reply_to_conv]
    resource :"helpdesk/conversation", :only => [:reply, :twitter, :facebook]
  end

  forward_ticket do
    resource :"helpdesk/ticket", :only => [:forward_conv]
    resource :"helpdesk/conversation", :only => [:forward]
  end

  edit_ticket do
    resource :"helpdesk/ticket", :only => [:edit, :update]
  end

  merge_or_split_ticket do
    resource :"helpdesk/ticket", :only => [:show_tickets_from_same_user, :confirm_merge, :complete_merge]
    resource :"helpdesk/ticket", :only => [:split_the_ticket]
  end

  view_private_conversations do
    # view needs to be decoupled
  end

  create_private_note do
    resource :"helpdesk/conversation", :only => [:note]
  end

  delete_conversation do
    resource :"helpdesk/note", :only => [:destroy]
  end

  edit_conversation do
    resource :"helpdesk/note", :only => [:edit, :update]
  end

  due_by_time do
    resource :"helpdesk/ticket", :only => [:change_due_by]    
  end

  ticket_priority do
    # Ticket priority is coupled with ticket update
  end

  close_ticket do
    resource :"helpdesk/ticket", :only => [:close, :close_multiple]
  end

  create_ticket_view do
    # resource :"helpdesk/ticket", :only => [:custom_view_save]
    # resource :"wf/filter", :only => [:save_filter, :delete_filter, :update_filter]
  end

  view_time_entries do
    resource :"helpdesk/time_sheet", :only => [:index, :create, :toggle_timer]
  end

  edit_time_entries do
    resource :"helpdesk/time_sheet", :only => [:edit, :update]
  end

  delete_ticket do
    resource :"helpdesk/ticket", :only => [:destroy, :restore]
  end

  view_solutions do
    resource :"solution/category", :only => [:index, :show]
    resource :"solution/folder", :only => [:index, :show]
    resource :"solution/article", :only => [:index, :show]
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

  create_edit_category_folder do
    resource :"solution/category", :only => [:new, :create, :edit, :update, :destroy, :reorder]
    resource :"solution/folder", :only => [:new, :create, :edit, :update, :destroy, :reorder]
  end

	view_forums do
    resource :forum_category, :only => [:index, :show]
    resource :forum, :only => [:index, :show]
    resource :topic, :only => [:index, :show, :vote, :destroy_vote, :users_voted]
    resource :post, :only => [:index, :show]
  end

  manage_forums do
    resource :forum_category, :only => [:new, :create, :edit, :update, :destroy, :reorder]
    resource :forum, :only => [:new, :create, :edit, :update, :destroy, :reorder]
    resource :topic, :only => [:update_stamp, :remove_stamp]
    resource :topic, :only => [:edit, :update, :update_lock], :owned_by => { :scoper => :topics }
    resource :post, :only => [:destroy, :edit, :update], :owned_by => { :scoper => :posts }
  end

  post_in_forums do
    resource :post, :only => [:create, :toggle_answer, :monitored]
  end

  create_forum_topic do
    resource :topic, :only => [:new, :create]
    resource :monitorship
  end

  edit_forum_content do
    # moved it to manage forums
  end

  delete_forum_topic do
    resource :topic, :only => [:destroy], :owned_by => { :scoper => :topics }
  end

	view_contacts do
		resource :contact, :only => [:index, :show, :hover_card]
		resource :customer, :only => [:index, :show]
    resource :agent, :only => [:show]
    resource :user, :only => [:index, :show]
	end

  edit_contact do
    resource :contact, :only => [:edit, :update]
    resource :customer, :only => [:edit, :update]
    resource :user, :only => [:edit, :update]
  end

  add_contact do
    resource :contact, :only => [:new, :create, :autocomplete, :quick_customer, :contact_email]
    resource :customer, :only => [:new, :create, :quick]
    resource :contact_import
    resource :user, :only => [:new, :create]
  end

  delete_contact do
    resource :contact, :only => [:destroy, :restore]
    resource :customer, :only => [:destroy]
    resource :user, :only => [:destroy]
  end

	view_reports do
		resource :report
		resource :"reports/timesheet_report"
		resource :"reports/customer_report"
		resource :"reports/helpdesk_report"
		resource :"reports/survey_report"
	end

	view_admin do
		resource :"admin/account_additional_setting"
		resource :"admin/business_calendar"
		resource :"admin/va_rule"
		resource :"admin/supervisor_rule"
		resource :"admin/automation"
	  resource :"social/twitter_handle", :only => [:index, :edit, :update, :destroy, :signin, :authdone, :search]
		resource :"social/facebook_page"
		resource :"admin/survey"
    resource :group
    resource :"admin/zen_import"
    resource :"admin/role"
    resource :"admin/product"
    resource :"admin/portal"
    resource :"admin/security"
    resource :"admin/home"
    resource :"admin/widget_config"
    resource :"integrations/application"
    resource :"integrations/installed_application"
    resource :"integrations/google_account"
        
	end

  manage_plan_billing do
    resource :subscription
  end

  manage_ticket_fields do
    resource :ticket_field
  end

  manage_canned_responses do
    resource :"admin/canned_response"
  end

  manage_email_settings do
    resource :"admin/email_config"
    resource :"admin/email_notification"
    resource :"admin/email_commands_setting"
  end

  manage_arcade_settings do
    resource :"admin/gamification"
    resource :"admin/quest"
  end

  edit_sla_policy do
    resource :"helpdesk/sla_policy"
  end

  rebrand_helpdesk do
    resource :account, :only => [:update, :edit, :delete_logo, :delete_fav]
  end

  client_manager do
  end

  # Authority::Authorization::PrivilegeList.privileges.each { |privilege| puts privilege}

end