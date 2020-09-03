require_relative 'api_privileges'
require_relative 'pipe_privileges'
require_relative 'channel_privileges'
require_relative 'channel_v2_privileges'

Authority::Authorization::PrivilegeList.build do

  # *************** TICKETS **********************

  manage_tickets do
    resource :"helpdesk/dashboard", :only => [:index, :show, :activity_list,:latest_activities,:latest_summary,:sales_manager, :tickets_summary, :achievements,
                                              :trend_count, :due_today, :overdue, :unresolved_tickets_dashboard, :unresolved_tickets_workload, :available_agents, :survey_info,
                                              :my_performance, :agent_performance, :group_performance, :channels_workload, :admin_glance, :agent_performance_summary,
                                              :group_performance_summary, :my_performance_summary, :top_agents_old_tickets, :top_customers_open_tickets]
    resource :"helpdesk/quest"
    resource :"helpdesk/leaderboard"
    resource :"helpdesk/note", :only => [:index, :agents_autocomplete,:public_conversation]
    resource :user, :only => [:delete_avatar, :me]
    resource :"helpdesk/reminder"
    resource :"helpdesk/authorization"
    resource :"search/autocomplete", :only => [:requesters, :agents, :companies, :tags]
    resource :"search/v2/autocomplete", :only => [:requesters, :agents, :companies, :tags, :company_users]
    resource :"search/v2/mobile/autocomplete", :only => [:requesters, :agents, :companies, :tags, :autocomplete_requesters]
    resource :"helpdesk/ticket", :only => [:show, :new, :create, :compose_email, :show, :index, :user_tickets,
                                           :user_ticket, :search_tweets, :custom_search, :latest_ticket_count, :add_requester, :view_ticket,
                                           :spam, :unspam, :execute_scenario, :pick_tickets,
                                           :get_ca_response_content, :merge_with_this_request, :print, :latest_note,
                                           :clear_draft, :save_draft, :prevnext, :component, :custom_search,
                                           :quick_assign, :canned_reponse, :full_paginate, :custom_view_save, :apply_template, :accessible_templates, :search_templates, :show_children,
                                           :filter_options, :filter_conditions, :activities, :status, :get_top_view, :recent_tickets, :old_tickets, :summary, :bulk_scenario,
                                           :execute_bulk_scenario, :activitiesv2, :activities_all, :link, :unlink, :ticket_association,
                                           :bulk_child_tkt_create, :associated_tickets, :sentiment_feedback, :refresh_requester_widget, :fetch_errored_email_details, :suppression_list_alert, :bulk_fetch_ticket_fields, :send_and_set_status]
    resource :"helpdesk/subscription"
    resource :"helpdesk/tag_use"
    resource :"helpdesk/tag"
    resource :"helpdesk/visitor"
    resource :"helpdesk/autocomplete"
    resource :"helpdesk/chat"
    resource :"mobile/ticket"
    resource :"mobile/automation"
    resource :"mobile/notification"
    resource :"mobile/setting"
    resource :"mobile_app_download"
    # Social - Twitter
    resource :"social/twitter_handle",
      :only => [:create_twicket, :feed, :tweet_exists, :send_tweet, :twitter_search]
    resource :"social/stream",
      :only => [ :index, :stream_feeds, :show_old, :fetch_new, :interactions]
    resource :"social/twitter",
        :only => [:user_info, :retweets, :twitter_search, :show_old, :fetch_new, :user_following]
    resource :"health_check"

    resource :"integrations/integrated_resource"
    resource :"integrations/jira_issue"
    resource :"integrations/oauth_util"
    resource :"integrations/user_credential"
    resource :"integrations/pivotal_tracker"
    resource :"integrations/cti/customer_detail"
    resource :"integrations/cti/screen_pop"
    resource :"integrations/quickbook"
    resource :"integrations/dynamicscrm", :only => [:widget_data]
    resource :"integrations/infusionsoft", :only => [:fetch_user]
    resource :"integrations/xero" , :only => [ :fetch , :render_accounts, :render_currency, :fetch_create_contacts, :get_invoice,  :create_invoices , :edit, :check_item_exists]
    resource :"integrations/hootsuite/home"
    resource :"integrations/hootsuite/ticket"
    resource :"integrations/sugarcrm", :only => [:renew_session_id, :check_session_id]
    resource :"integrations/service_proxy", :only => [:fetch]
    resource :"integrations/slack_v2", :only => [:add_slack_agent]
    resource :"integrations/data_pipe"
    resource :"integrations/cloud_elements/crm", :only => [:fetch]
    resource :"integrations/microsoft_team", :only => [:authorize_agent]

    # Used by API V2 Search
    resource :"api_search/ticket", :only => [:index]
    
    resource :"helpdesk/conversation", :only => [:note, :full_text, :broadcast]
    resource :"helpdesk/canned_response"
    resource :"helpdesk/ca_folder"
    resource :"helpdesk/scenario_automation"
    resource :agent, :only => [:toggle_availability, :list]
    resource :"search/home", :only => [:index, :suggest, :recent_searches_tickets, :remove_recent_search]
    resource :"search/v2/suggest", :only => [:index]
    resource :"search/v2/mobile/suggest", :only => [:index]
    resource :"search/solution", :only => [:related_solutions, :search_solutions]
    resource :"search/v2/solution", :only => [:related_solutions, :search_solutions]
    resource :"search/v2/mobile/related_article", :only => [:index]
    resource :"search/ticket", :only => [:index]
    resource :"search/ticket_association", :only => [:index, :recent_trackers]
    resource :"search/v2/ticket_association", :only => [:index, :recent_trackers]
    resource :"search/v2/ticket", :only => [:index]
    resource :"search/v2/mobile/merge_ticket", :only => [:index]
    resource :"search/v2/spotlight", :only => [:all, :tickets]
    resource :"chat", :only => [:create_ticket, :add_note, :agents, :enable,
                                :index, :visitor, :get_groups, :update_site,
                                :toggle, :trigger, :export, :download_export,
                                :update_availability, :create_shortcode,
                                :delete_shortcode, :update_shortcode
                                ]
    resource :"chat_widget", :only => [:update, :toggle, :enable]
    resource :"helpdesk/survey"
    resource :"admin/data_export" , :only => [:download]
    resource :"notification/product_notification", :only => [:index]
    resource :"notification/user_notification"
    resource :"helpdesk/common", :only => [:fetch_company_by_name, :status_groups]

    # ticket_templates
    resource :"helpdesk/ticket_template"

    #canned_response
    resource :"helpdesk/canned_responses/folder", :only => [:index, :show]
    resource :"helpdesk/canned_responses/response"

    resource :"helpdesk/archive_ticket", :only => [:show, :index, :custom_search, :latest_note,
                                                    :full_paginate,  :activities, :component, :prevnext, :activitiesv2, :print_archive]
    resource :"helpdesk/archive_note", :only => [:index, :full_text]
    resource :"helpdesk/collab_ticket"

    resource :"wf/filter", :only => [:index, :update_filter, :save_filter, :delete_filter]
    resource :"profile"

    # Used for API V2 canned_response
    resource :"canned_response_folder", only: [:index, :show]
    resource :"canned_response", only: [:index, :show, :folder_responses]

    # Used for API V2 scenario_automations
    resource :"scenario_automation", only: [:index]

    # Used for API V2
    resource :"conversation", only: [:create, :ticket_conversations]
    resource :"ticket", :only => [:show, :create, :index, :search]
    resource :"ticket_summary", only: [:update, :show]

    resource :"satisfaction_rating", :only => [:survey_results]

    resource :"year_in_review", :only => [:clear]

    # This privilege should only be used for API. This should have only read permission.
    # Agent who has access to ticket create will obviously know the custom field names.
    # So access to read the list of custom fields for an account through API should also be given at the same level of privilege as ticket create.
    resource :api_ticket_field, :only => [:index]
    resource :"announcement", :only => [:index, :account_login_url]
    resource :"email_preview"
    resource :"doorkeeper/authorize"
    resource :"archive/ticket", :only => [:show, :destroy]
    resource :"archive/conversation", :only => [:ticket_conversations]
    resource :"archive/tickets/activity", only: [:index]
    resource :"admin/freshmarketer", only: %i[sessions session_info]
    resource :"support/canned_form", only: [:preview]
    resource :"settings/helpdesk", only: [:index]
  end

  export_tickets do
    resource :"helpdesk/ticket", :only => [:configure_export, :export_csv]
    resource :"helpdesk/archive_ticket", :only => [:configure_export, :export_csv]
    resource :"archive/ticket", :only => [:export]
  end

  reply_ticket do
    resource :"helpdesk/ticket", :only => [:reply_to_conv]
    resource :"helpdesk/conversation", only: [:reply, :twitter, :facebook, :traffic_cop, :ecommerce]
    resource :"social/twitter_handle", :only => [:send_tweet]
    # In bulk actions you can reply even if you do not have edit_ticket_properties
    resource :"helpdesk/ticket", :only => [:update_multiple_tickets]
    resource :"helpdesk/bulk_ticket_action"
    # Used for API
    resource :"helpdesk/note", :only => [:create]
    resource :"social/twitter",
      :only => [:create_fd_item, :reply, :retweet, :post_tweet, :favorite, :unfavorite, :followers, :follow, :unfollow]

    resource :"support/canned_form", only: [:preview]

    # Used for API V2
    resource :"conversation", :only => [:reply]
  end

  forward_ticket do
    resource :"helpdesk/ticket", :only => [:forward_conv, :reply_to_forward]
    resource :"helpdesk/conversation", :only => [:forward, :reply_to_forward]
    resource :"api_conversation", :only => [:forward, :reply_to_forward]
  end

  merge_or_split_ticket do
    resource :"helpdesk/merge_ticket"
    resource :"helpdesk/ticket", :only => [:split_the_ticket]
  end

  edit_ticket_properties do
    resource :"helpdesk/ticket", :only => [:edit, :update, :update_ticket_properties, :assign_to_agent, :assign, :close,
                                           :close_multiple, :update_multiple_tickets, :change_due_by]
    resource :"helpdesk/bulk_ticket_action"

    # Used for API V2
    resource :"ticket", :only => [:update, :assign]
  end

  edit_conversation do
    resource :"helpdesk/note", :only => [:destroy, :restore]

    # Used for API V2
    resource :conversation, only: [:destroy]
    resource :ticket_summary, only: [:destroy]
  end

  edit_note do
    resource :"helpdesk/note", :only => [:edit, :update], :owned_by => { :scoper => :notes }

    # Used for API V2
    resource :"conversation", only: [:update], :owned_by => { :scoper => :notes }
    resource :"ticket_summary", only: [:update], :owned_by => { :scoper => :notes }
  end

  view_time_entries do
    resource :"helpdesk/time_sheet", :only => [:index, :new, :create, :toggle_timer , :show]

    # Used for API V2
    resource :"time_entry", :only => [:index, :create, :ticket_time_entries]
  end

  edit_time_entries do
    resource :"helpdesk/time_sheet", :only => [:edit, :update, :destroy], :owned_by =>
      { :scoper => :time_sheets }

    # Used for API V2
    resource :"time_entry", :only => [:update, :destroy, :toggle_timer], :owned_by =>
      { :scoper => :time_sheets }
  end

  delete_ticket do
    resource :"helpdesk/ticket", :only => [:destroy, :restore, :delete_forever, :delete_forever_spam,  :empty_trash, :empty_spam]

    # Used for API V2
    resource :"ticket", :only => [:restore, :destroy]
  end

  # ************** SOLUTIONS **************************

  view_solutions do
    resource :"solution/category", :only => [:index, :show, :navmenu, :sidebar, :all_categories]
    resource :"solution/folder", :only => [:index, :show]
    resource :"solution/article", :only => [:index, :show, :voted_users, :show_master]
    resource :"search/home", :only => [:solutions]
    resource :"search/solution", :only => [:index]
    resource :"search/v2/spotlight", :only => [:solutions]
    resource :"helpdesk/ticket", :only => [:get_solution_detail]
    resource :"solution/draft", :only => [:index]
    resource :"api_search/solution", only: [:results]

    # Used by V2 API
    resource :"api_solutions/category", :only => [:index, :show]
    resource :"api_solutions/folder", :only => [:category_folders, :show]
    resource :"api_solutions/article", :only => [:folder_articles, :show]
  end

  create_and_edit_article do
    resource :"solution/article", :only => [:new, :create, :edit, :update, :delete_tag, :reorder, :properties, :move_to, :move_back, :mark_as_outdated, :mark_as_uptodate]
    resource :"solution/tag_use"
    resource :solutions_uploaded_image, :only => [:create, :create_file, :index]
    resource :"solution/draft", :only => [:autosave, :publish, :attachments_delete, :destroy]

    # Used by V2 API
    resource :"api_solutions/article", :only => [:create, :update]
  end


  #--start- This resource mapping is here to handle delta phase backward compatablility.
  publish_solution do
    resource :"solution/article", :only => [:new, :create, :edit, :update, :delete_tag, :reorder, :properties, :move_to, :move_back, :mark_as_outdated, :mark_as_uptodate]
    resource :"solution/tag_use"
    resource :solutions_uploaded_image, :only => [:create, :create_file, :index]
    resource :"solution/draft", :only => [:autosave, :publish, :attachments_delete, :destroy]

    # Used by V2 API
    resource :"api_solutions/article", :only => [:create, :update]
  end
  #--end-

  delete_solution do
    resource :"solution/article", :only => [:destroy, :reset_ratings], :owned_by =>
                                  { :scoper => :solution_articles }
    resource :"solution/draft", :only => [:destroy]

    # Used by V2 API
    resource :"api_solutions/article", :only => [:destroy], :owned_by => { :scoper => :solution_articles }
  end

  manage_solutions do
    resource :"solution/category", :only => [:new, :create, :edit, :update, :destroy, :reorder]
    resource :"solution/folder", :only => [:new, :create, :edit, :update, :destroy, :reorder, :move_to, :move_back, :visible_to]
    resource :"solution/article", :only => [:translate_parents]

    # Used by V2 API
    resource :"api_solutions/category", :only => [:create, :update, :destroy]
    resource :"api_solutions/folder", :only => [:create, :update, :destroy]
  end

  # ************** FORUMS **************************


  view_forums do
    resource :discussion, :only => [:index, :show, :your_topics, :sidebar, :categories]
    resource :"discussions/forum", :only => [:show, :followers]
    resource :"discussions/topic", :only => [:show, :component, :latest_reply, :vote, :destroy_vote, :users_voted]
    resource :forum_category, :only => [:index, :show]
    resource :forum, :only => [:index, :show]
    resource :topic, :only => [:index, :show, :vote, :destroy_vote]
    resource :post, :only => [:index, :show, :create, :toggle_answer, :monitored, :best_answer]
    resource :"discussions/post", :only => [:index, :show, :create, :toggle_answer, :monitored, :best_answer, :users_voted]
    # review code for monitorship?
    resource :"search/home", :only => [:topics]
    resource :"search/forum", :only => [:index]
    resource :"search/v2/spotlight", :only => [:forums]
    resource :"search/merge_topic", :only => [:index]
    resource :"search/v2/merge_topic", :only => [:search_topics]
    resource :forums_uploaded_image, :only => [:index, :create]
    resource :monitorship, :only => [:followers]

    # Used for API V2
    resource :"api_discussions/category", :only => [:index, :show]
    resource :"api_discussions/forum", :only => [:show, :category_forums, :follow, :unfollow, :is_following]
    resource :"api_discussions/topic", :only => [:show, :forum_topics, :follow, :unfollow, :is_following, :followed_by, :participated_by]
    resource :"api_discussions/api_comment", :only => [:create, :topic_comments]
  end

  # create_edit_forum_category
  manage_forums do
    resource :forum_category, :only => [:new, :create, :edit, :update, :destroy, :reorder]
    resource :discussion, :only => [:new, :create, :edit, :update, :destroy, :reorder]
    resource :"discussions/forum", :only => [:new, :create, :edit, :update, :destroy, :reorder]
    resource :forum, :only => [:new, :create, :edit, :update, :destroy, :reorder]

    # Used for API V2
    resource :"api_discussions/category", :only => [:create, :update, :destroy]
    resource :"api_discussions/forum", :only => [:create, :update, :destroy]
  end

  # create_forum_topic
  create_topic do
    resource :"discussions/topic", :only => [:new, :create ]
    resource :topic, :only => [:new, :create ]
    resource :forums_uploaded_image, :only => [:create]
    # Used for API V2
    resource :"api_discussions/topic", :only => [:create]
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
    # Used for API V2
    resource :"api_discussions/topic", :only => [:update], :owned_by => { :scoper => :topics }
    resource :"api_discussions/api_comment", :only => [:destroy], :owned_by => { :scoper => :posts }
  end

  # delete_forum_topic
  delete_topic do
    resource :"discussions/topic", :only => [:destroy, :destroy_multiple], :owned_by => { :scoper => :topics }
    resource :topic, :only => [:destroy, :destroy_multiple], :owned_by => { :scoper => :topics }
    resource :"discussions/moderation"
    resource :"discussions/unpublished"
    # Used for API V2
    resource :"api_discussions/topic", :only => [:destroy], :owned_by => { :scoper => :topics }
  end

  # ************** CONTACTS **************************

  view_contacts do
    resource :contact, :only => [:index, :show, :hover_card, :hover_card_in_new_tab, :contact_details_for_ticket, :view_conversations]
    resource :customer, :only => [:index, :show] #should deprecate
    resource :company,  :only => [:index, :show, :component]
    resource :agent, :only => [:show]
    resource :user, :only => [:index, :show]
    resource :"search/customer", :only => [:index]
    resource :"search/v2/spotlight", :only => [:customers]
    resource :"integrations/service_proxy", :only => [:fetch]
    resource :customers_import

    # Used by V2 API
    resource :"api_contact", :only => [:index, :show]
    resource :"api_company", :only => [:index, :show]
    resource :"contacts/misc", only: [:send_invite]
    resource :"api_search/company", only: [:index]
  end

  # add_or_edit_contact
  manage_contacts do
    resource :contact, :only => [:new, :create, :autocomplete, :quick_contact_with_company,
               :create_contact, :update_contact, :update_description_and_tags, :contact_email, :edit, :update, :verify_email]
    resource :contact_merge
    resource :"search/v2/merge_contact", :only => [:index]
    resource :user_email
    resource :"segment/identify"
    resource :"segment/group"
    # is this the correct place to put this ?
    resource :user, :only => [:new, :create, :edit, :update]
    resource :"helpdesk/ticket", :only => [:update_requester]

    # Used by V2 API
    resource :"api_contact", :only => [:create, :update]
    resource :api_contact_import, only: [:index, :create, :show, :cancel]

    # Used by API V2 Search
    resource :"api_search/contact", :only => [:index]

    # This privilege should only be used for API. This should have only read permission. 
    # Agent who has access to contact/company create will obviously know the custom field names.
    # So access to read the list of custom fields for an account through API should also be given at the same level of privilege as contact/company create.
    resource :api_contact_field, :only => [:index]
    resource :"contacts/merge", only: [:merge]
    resource :"search/autocomplete", only: [:companies]
    resource :"search/v2/autocomplete", only: [:companies]
    resource :"search/v2/mobile/autocomplete", only: [:companies]
  end

  manage_companies do
    resource :customer, only: [:new, :create, :edit, :update] # should deprecate
    resource :company, only: [:new, :create, :edit, :update, :create_company, :update_company, :update_notes, :quick, :sla_policies]
    resource :api_company, only: [:create, :update]

    # This privilege should only be used for API. This should have only read permission.
    # Agent who has access to contact/company create will obviously know the custom field names.
    # So access to read the list of custom fields for an account through API
    # should also be given at the same level of privilege as contact/company create.
    resource :api_company_field, only: [:index]
    resource :api_company_import, only: [:index, :create, :show, :cancel]
  end

  delete_contact do
    resource :contact, :only => [:destroy, :restore, :unblock]
    resource :customer, :only => [:destroy] #should deprecate
    # is this the correct place to put this ?
    resource :user, :only => [:destroy, :block]

    # Used by V2 API
    resource :"api_contact", :only => [:destroy, :restore, :hard_delete]
  end

  delete_company do 
    resource :company, :only => [:destroy]
    resource :"api_company", :only => [:destroy]
  end


  export_customers do
    resource :contact, :only =>  [:configure_export, :export_csv]
    resource :company,  :only => [:configure_export, :export_csv]
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
    resource :"reports/custom_survey_report"
    resource :"reports/freshchat/summary_report"
    resource :"reports/timesheet_report", :only => [:index, :report_filter, :save_reports_filter, :update_reports_filter, :delete_reports_filter, :time_entries_list]
    resource :"reports/report_filter"
    resource :"reports/v2/tickets/report", :only =>[ :index, :fetch_metrics, :fetch_ticket_list, :fetch_active_metric,
                                                      :save_reports_filter, :update_reports_filter, :delete_reports_filter,
                                                      :fetch_qna_metric, :fetch_insights_metric, :save_insights_config,
                                                      :fetch_recent_questions, :fetch_insights_config]

    resource :"helpdesk/dashboard", :only => [:unresolved_tickets, :unresolved_tickets_data]
    resource :"api_product", :only => [:index]
    resource :"reports/scheduled_export"
    resource :export, :only => [:ticket_activities]
    resource :"reports/v2/tickets/report", :only => [:fetch_threshold_value]
    resource :"year_in_review", :only => [:share]
  end

  view_analytics do
    resource :"reports/freshvisual", only: [:download_schedule_file]
  end

  # NOTE: Resource(controller action) related to scheduling is not added here because save reports and scheduling reports use the same action
  # Currently schedule reports uses this privilege as user.privilege and not as owns_object
  export_reports do
    resource :"reports/v2/tickets/report", :only => [:configure_export, :export_tickets, :export_report, :email_reports,  :download_file]
    resource :"reports/timesheet_report", :only => [:export_csv, :generate_pdf, :export_pdf]
    resource :"reports/freshchat/summary_report", :only => [:export_pdf]
  end

  # ************** ADMIN **************************

  view_admin do
    resource :"admin/home"
  end

  # ************** Operational Admin ***************

  manage_users do
    # NOTE: The agent show action is also allowed in view_contacts privilege
    resource :agent, :only => [:new, :create, :edit, :update, :index, :destroy, :show, :delete_avatar,
                               :restore, :convert_to_user, :reset_password, :create_multiple_items, :convert_to_contact,
                               :configure_export, :export_csv, :reset_score, :search_in_freshworks]
    resource :agent, :only => [:toggle_shortcuts], :owned_by => { :scoper => :agents }
    resource :contact, :only => [:make_agent, :make_occasional_agent]
    resource :activation, :only => [:send_invite]
    resource :user, :only => [:assume_identity, :assumable_agents]

    # Used by V2 API
    resource :"api_contact", :only => [:make_agent]
    resource :"api_agent", :only => [:show, :index, :update, :destroy, :create, :export, :export_s3_url, :update_multiple, :create_multiple, :availability_count]
  end

  manage_availability do
    resource :group, :only => [:index, :show, :edit, :update, :toggle_roundrobin, :user_skill_exists]
    resource :"helpdesk/dashboard",:only => [:agent_status]
    resource :"admin/user_skill"
    resource :api_agent, only: [:availability_count, :index]
  end

  manage_canned_responses do
    resource :"helpdesk/canned_responses/folder"
    resource :"canned_response", only: %i[create update create_multiple]
    resource :"canned_response_folder", :only => [:create, :update]
  end

  manage_dispatch_rules do
    resource :"admin/va_rule"
    resource :"admin/observer_rule"
  end

  manage_supervisor_rules do
    resource :"admin/supervisor_rule"
  end

  manage_email_settings do
    resource :"admin/dkim_configuration"
    resource :"admin/email_config"
    resource :"admin/email_notification"
    resource :"admin/dynamic_notification_template"
    resource :"admin/email_commands_setting"
    resource :"admin/account_additional_setting", except: [:enable_skip_mandatory, :disable_skip_mandatory]
    resource :"api_email_config", :only => [:index, :show]
  end

  manage_requester_notifications do
    resource :"admin/email_notification"
    resource :"admin/dynamic_notification_template"
  end

  # **************** super admin *******************
  # super_admin
  admin_tasks do
    resource :"admin/business_calendar"
    resource :"social/twitter_handle", :only => [:index, :edit, :update, :destroy, :signin, :authdone, :search, :activate]
    resource :"social/streams"
    resource :"admin/social/facebook_stream", :only => [:index, :edit, :update]
    resource :"admin/social/facebook_page", :only => [:destroy, :enable_pages]
    resource :"social/welcome"
    resource :"contact", :only => [:change_password, :update_password]
    resource :"social/facebook_page"
    resource :"admin/social/facebook_tab", :only => [:remove]
    resource :"admin/survey"
    resource :"admin/custom_survey"
    resource :"support/custom_surveys", only: [:preview, :preview_questions]
    resource :group
    resource :ticket_field
    resource :"admin/requester_widget", :only => [:get_widget, :update_widget]
    resource :"admin/contact_field"
    resource :"admin/company_field"
    resource :"admin/role"
    resource :"admin/skill"
    resource :"admin/product"
    resource :"admin/portal"
    resource :"admin/security"
    resource :"admin/home"
    resource :"admin/widget_config"
    resource :"integrations/application"
    resource :"integrations/installed_application"
    resource :"integrations/google_account"
    resource :"integrations/remote_configuration"
    resource :"integrations/dynamicscrm", :only => [:settings, :edit, :settings_update, :fields_update]
    resource :"integrations/marketplace/shopify", :only => [:install, :create, :landing, :remove_store, :edit, :update]
    resource :"integrations/infusionsoft", :only => [:install, :edit, :fields_update]
    resource :"integrations/sugarcrm", :only => [:settings, :edit, :settings_update, :fields_update]
    resource :"integrations/magento", :only => [:new, :edit, :update]
    resource :"integrations/fullcontact", :only => [:new, :edit, :update]
    resource :"admin/freshcaller"
    resource :"admin/freshcaller/signup"
    resource :"admin/gamification"
    resource :"admin/quest"
    resource :"helpdesk/sla_policy"
    resource :"admin/account_additional_setting", only: [:enable_skip_mandatory, :disable_skip_mandatory]
    resource :account, only: [:update, :edit, :delete_logo, :delete_favicon, :manage_languages, :update_languages]
    resource :"admin/template"
    resource :"admin/page"
    resource :"support/preview"
    resource :"admin/chat_setting"
    resource :"admin/chat_widget"
    resource :"api_webhook", :only => [:create, :destroy]
    resource :"admin/social/stream"
    resource :"admin/social/twitter_stream"
    resource :"admin/social/twitter_handle"
    resource :"solution/article", :only => [:change_author]
    resource :"helpdesk/ticket", :only => [:update_all_tickets]
    resource :"helpdesk/select_all_ticket_action"
    resource :"helpdesk/dashboard",:only => [:agent_status,:load_ffone_agents_by_group ]
    resource :"integrations/xero", :only => [:authorize, :authdone, :update_params]
    resource :"integrations/github", :only => [:new, :install, :edit, :update, :oauth_install]
    resource :"integrations/marketplace/quickbooks_sso", :only => [:landing]
    resource :"integrations/marketplace/shopify", :only => [:landing]
    resource :"integrations/salesforce"
    resource :"integrations/freshsale"
    resource :"integrations/slack_v2", :only => [:oauth, :new, :install, :edit, :update]
    resource :"integrations/outlook_contact", :only => [:install, :settings, :edit, :destroy, :update, :render_fields, :new]
    resource :"integrations/cti_admin"
    resource :"admin/integrations/freshplug"
    resource :"admin/marketplace/app"
    resource :"admin/marketplace/extension"
    resource :"admin/marketplace/installed_extension"
    resource :"doorkeeper/authorization"
    resource :"admin/ecommerce/account",:only => [:index]
    resource :"admin/ecommerce/ebay_account"
    resource :"integrations/marketplace_app"
    resource :"integrations/cloud_elements/crm", :only => [:instances, :edit, :update, :settings, :create]
    resource :"integrations/microsoft_team", :only => [:oauth, :install]
    resource :"integrations/google_hangout_chat", :only => [:oauth, :install]
    resource :"user", :only => [:enable_falcon_for_all, :disable_old_helpdesk]
    resource :"admin/onboarding"

    # Used by API V2
    resource :api_ticket_field, :only => [:index]
    resource :api_contact_field, :only => [:index]
    resource :api_company_field , :only => [:index]
    resource :"api_business_hour", :only => [:index, :show]
    resource :"api_group", :only => [:create, :update, :destroy, :index, :show]
    resource :"api_sla_policy", :only => [:index, :update, :create]
    resource :"api_product", :only => [:show, :index]
    resource :survey, :only => [:index]
    resource :"satisfaction_rating", :only => [:create, :index]
    resource :"api_role", :only => [:index, :show]
    resource :"api_integrations/cti", :only => [:create, :index]
    resource :"email_preview"
    resource :"admin/freshchat", :only => [:index, :create, :update, :toggle, :signup]
    resource :"admin/freshmarketer", only: %i[index link unlink enable_integration disable_integration enable_session_replay domains]
    resource :"admin/custom_translations/upload", only: [:upload]
    resource :"admin/custom_translation", only: [:upload]
  end

  manage_account do
    resource :account, only: [:show, :cancel, :update_domain, :validate_domain, :anonymous_signup_complete]
    resource :account_configuration
    resource :"admin/data_export"
    resource :subscription # plans and billing
    resource :subscription_invoice
    resource :"admin/zen_import"
    # new item day passes && getting started
    resource :"admin/day_pass"
    resource :"admin/getting_started"
    resource :"agent", :only => [:api_key]
    resource :"rake_task", only: [:run_rake_task]
    resource :automation_essential
    resource :"testing/freshid_api"
  end

  manage_skills do
    resource :"admin/skill"
    resource :"admin/user_skill"
    resource :"admin/skill", :only => [:import, :process_csv]
    resource :"agent", :only => [:export_skill_csv]
  end

  client_manager do
  end

  contractor do
  end
  # Authority::Authorization::PrivilegeList.privileges.each { |privilege| puts privilege}

end
