Authority::Authorization::PrivilegeList.build do
  manage_calls do
    resource :"ember/freshcaller/call", only: [:create]
  end

  manage_tickets do
    resource :"ember/bootstrap"
    resource :"ember/bootstrap/agents_group"
    resource :"ember/bootstrap/preference"
    resource :"ember/tickets/collab", only: [:notify]
    resource :"ember/tickets/delete_spam", only: %i[spam bulk_spam unspam bulk_unspam]
    resource :"ember/tickets/activity"
    resource :"ember/canned_response", only: %i[search]
    resource :"ember/ticket", only: %i[index show create execute_scenario spam latest_note create_child_with_template parse_template fetch_errored_email_details suppression_list_alert ticket_field_suggestions]
    resource :"ember/tickets/bulk_action", only: %i[bulk_execute_scenario bulk_link bulk_unlink]
    resource :"ember/tickets/associate", only: [:link, :unlink, :associated_tickets, :prime_association]
    resource :"ember/ticket_filter", only: [:index, :show, :create, :update, :destroy]
    resource :"ember/attachment", only: [:create, :show]
    resource :"ember/freshcaller/setting", only: %i[index desktop_notification redirect_url]
    resource :"ember/conversation", only: %i[create ticket_conversations full_text]
    resource :"ember/ticket_field", only: [:index]
    resource :"ember/todo", only: [:index, :create, :update, :destroy]
    resource :"ember/twitter_handles", only: %i[index check_following]
    resource :"ember/marketplace_app", only: [:index]
    resource :'admin/canned_form', only: [:index, :show, :create_handle]
    resource :"tickets/bot_response", only: %i[show update]
    resource :"tickets/bulk_action", only: %i[bulk_archive]
    resource :"tickets/subscription"

    resource :"ember/agent", only: %i[index me achievements update]
    resource :"ember/group", only: [:index]
    resource :"ember/survey", only: [:index, :show]
    resource :"ember/dashboard/activity", only: [:index]
    resource :"ember/portal", only: [:index]
    resource :"ember/email_config", only: [:index, :search, :show]
    resource :"ember/dashboard", only: %i[scorecard show survey_info]
    resource :"ember/dashboard/quest", only: %i[index]
    resource :"ember/contact_field", only: [:index]
    resource :"ember/company_field", only: [:index]
    resource :"ember/livechat_setting", only: [:index]
    resource :"ember/installed_application", only: [:index, :show, :fetch, :create]
    resource :"ember/integrated_resource"
    resource :"ember/integrated_user"

    resource :"ember/search/ticket", only: [:results]
    resource :"api_search/autocomplete", only: %i[requesters agents companies companies_search tags]
    resource :"ember/leaderboard", only: [:agents, :groups]
    resource :"ember/product_feedback"
    resource :"ember/ticket_template", only: %i[show index]
    resource :"ember/search/multiquery", only: [:search_results]
    resource :"ember/search/logger", only: [:log_click]
    resource :"ember/year_in_review", only: %i[index clear]
    resource :"ember/custom_dashboard", only: %i[widgets_data show index bar_chart_data omni_widget_data]
    resource :"settings/helpdesk", only: [:index]
    resource :'ember/rt', only: [:show]
    resource :"out_of_office", only: %i[index show create update destroy]
    resource :'ember/agent_assist', only: [:bots]
    resource :agent_status, only: [:index]
    resource :api_agent, only: [:fetch_availability, :update_availability]
    resource :account_admin, only: [:preferences]
    resource :'admin/group', only: [:index]
  end

  view_secure_field do
    resource :'ember/ticket', only: %i[vault_token]
    resource :ticket, only: %i[vault_token]
  end

  manage_account do
    resource :"channel/freshcaller/account", only: [:update, :destroy]
    resource :"admin/trial_subscription", only: [:create, :cancel]
    resource :account_admin, only: [:update, :disable_billing_info_updation, :preferences=]
    resource :"admin/api_account", only: [:cancel, :download_file, :support_tickets, :reactivate]
    resource :"admin/api_data_export", only: [:account_export]
    resource :"ember/admin/onboarding", only: %i[update_activation_email resend_activation_email update_channel_config suggest_domains validate_domain_name customize_domain anonymous_to_trial]
  end

  manage_email_settings do
    resource :"ember/admin/onboarding", only: %i[forward_email_confirmation test_email_forwarding]
    resource :"admin/api_email_notification"
    resource :"email/setting", only: %i[show update]
    resource :"email/mailbox"
    resource :"notifications/email/bcc", only: %i[update show]
    resource :"ember/email/mailbox"
  end

  reply_ticket do
    resource :"ember/conversation", only: %i[reply facebook_reply tweet ecommerce_reply reply_template broadcast undo_send channel_reply]
    resource :"ember/tickets/draft", only: %i[save_draft show_draft clear_draft]
    resource :"ember/tickets/bulk_action", only: [:bulk_update]
    resource :"ember/agent", only: [:enable_undo_send, :disable_undo_send]
  end

  forward_ticket do
    resource :"ember/conversation", only: %i[forward_template note_forward_template latest_note_forward_template reply_to_forward_template]
  end

  merge_or_split_ticket do
    resource :"ember/tickets/merge", only: [:merge]
    resource :"ember/ticket", only: [:split_note]
  end

  edit_note do
    resource :"ember/conversation", only: [:update], owned_by: { scoper: :notes }
  end

  delete_contact do
    resource :"ember/contact", only: [:bulk_delete, :destroy, :bulk_restore, :restore, :whitelist, :bulk_whitelist, :hard_delete]
  end

  delete_company do
    resource :"ember/company", only: [:bulk_delete, :destroy]
  end

  view_contacts do
    resource :"ember/contact", only: %i[index show activities bulk_send_invite timeline]
    resource :"ember/company", only: %i[index show activities]
    resource :"ember/contact/todo", only: [:index]
    resource :"ember/search/customer", only: [:results]
    resource :customer_note, only: [:show, :index]
    resource :"ember/search/multiquery", only: [:search_results]
    resource :"ember/segments/contact_filter", only: [:index]
    resource :"ember/segments/company_filter", only: [:index]
  end

  manage_contacts do
    resource :"ember/contact", only: [:create, :update, :quick_create]
    resource :"ember/tickets/requester", only: [:update]
    resource :"ember/contact/todo", only: [:create, :update, :destroy]
    resource :customer_note, only: [:create, :update, :destroy]
    resource :"api_search/autocomplete", only: [:companies, :companies_search]
  end

  manage_companies do
    resource :"ember/company", only: [:create, :update]
  end

  manage_users do
    resource :"ember/contact", only: %i[make_agent assume_identity]
    resource :"ember/agent", only: %i[show update destroy assume_identity search_in_freshworks]
    resource :"bulk_api_job", only: %i[show]
    resource :"ember/admin/gamification/scoreboard_level", only: [:index]
    resource :"admin/api_account", only: [:agents_limit]
    resource :api_role, only: [:index, :show]
  end

  delete_topic do
    resource :"ember/dashboard", only: [:moderation_count]
  end

  manage_availability do
    resource :"ember/group", only: [:show, :index, :update]
    resource :"ember/agent", only: %i[update]
    resource :"ember/ocr_proxy"
    resource :"ember/freddy"
    resource :"ember/flow"
    resource :'ember/omni_channel', only: [:index]
    resource :'admin/group', only: [:show, :index, :update]
    resource :api_role, only: [:index, :show]
    resource :api_business_hour, :only => [:index, :show]
    resource :"admin/groups/agent", only: [:index]
  end

  delete_ticket do
    resource :"ember/tickets/delete_spam", only: %i[empty_trash empty_spam delete_forever destroy bulk_delete restore bulk_restore]
  end

  admin_tasks do
    resource :"admin/sandbox", only: [:create, :index, :destroy, :diff, :merge]
    resource :"ember/contact", only: [:update_password]
    resource :'ember/trial_widget', only: %i[index sales_manager complete_step]
    resource :'ember/contact_password_policy', only: [:index]
    resource :'ember/agent_password_policy', only: [:index] # Not using it now.
    resource :"ember/group", only: [:index, :create, :update, :show, :destroy]
    resource :api_role, only: [:index, :bulk_update]
    resource :'admin/canned_form'
    resource :"ember/portal", only: [:show, :update]
    resource :audit_log, only: [:filter, :export, :event_name, :export_s3_url]
    resource :"admin/holiday", only: [:show]
    resource :'ember/omni_channel', only: [:index]
    resource :"admin/subscription", only: [:show, :plans, :fetch_plan, :update, :estimate, :update_payment, :estimate_feature_loss]
    resource :"ember/ocr_proxy"
    resource :"ember/freddy"
    resource :"ember/flow"
    resource :'ember/admin/advanced_ticketing', only: [:create, :destroy, :insights]
    resource :help_widget, only: [:index, :create, :show, :update, :destroy]
    resource :"help_widgets/suggested_article_rule", only: [:index, :create, :update, :destroy]
    resource :"admin/trial_subscription", only: [:usage_metrics]
    resource :"admin/automation", only: [:index, :create, :show, :update, :destroy]
    resource :"admin/custom_translations/upload", only: [:upload]
    resource :"admin/custom_translation", only: [:upload]
    resource :"admin/custom_translations/download", only: [:primary, :secondary]
    resource :"admin/custom_translation", only: [:download]
    resource :"settings/helpdesk", only: [:update]
    resource :"admin/account_feature", only: [:create, :destroy]
    resource :"api_search/automation", only: [:results]
    resource :"ember/admin/freddy_skill", only: [:index, :show, :update]
    resource :"admin/ticket_field", only: [:create, :update, :destroy, :show, :index]
    resource :"admin/section", only: [:create, :update, :destroy, :show, :index]
    resource :"admin/security_key", only: [:regenerate_widget_key]
    resource :"admin/api_security", only: [:update, :show]
    resource :"admin/freshcaller_account", only: [:show, :create, :link, :update, :enable, :disable, :destroy, :credit_info]
    resource :"admin/api_skill", only: [:index, :create, :show, :update, :destroy]
    resource :"admin/shift", only: [:index, :show, :create, :update, :destroy]
    resource :field_service_management, only: [:update_settings, :show_settings]
    resource :"settings/helpdesk/field_service", only: [:update_settings, :show_settings]
    resource :"ember/sla_policy", only: [:index, :show, :create, :update, :destroy]
    resource :"admin/api_business_calendar", only: [:index, :show, :create, :update, :destroy]
    resource :agent_status, only: [:show, :create, :update, :destroy]
    resource :'admin/group', only: [:index, :show, :destroy, :create, :update]
    resource :"admin/groups/agent", only: [:index, :update]
  end

  edit_ticket_properties do
    resource :"ember/ticket", only: %i[update update_properties]
    resource :"ember/tickets/bulk_action", only: [:bulk_update]
  end

  view_time_entries do
    resource :"ember/time_entry", only: %i[index create ticket_time_entries show]
  end

  edit_time_entries do
    resource :"ember/time_entry", only: %i[update destroy toggle_timer], owned_by: { scoper: :time_sheets }
  end

  export_customers do
    resource :"contacts/misc", only: [:export, :export_details]
    resource :"companies/misc", only: [:export, :export_details]
  end

  export_tickets do
    resource :"ember/ticket", only: [:export_csv]
  end

  view_forums do
    resource :"ember/search/topic", only: [:results]
    resource :"ember/search/multiquery", only: [:search_results]
    resource :'ember/discussions/topic', only: [:show, :first_post]
  end

  view_solutions do
    resource :'ember/solutions/article', only: %i[index article_content folder_articles show votes filter untranslated_articles suggested]
    resource :'ember/solutions/category', only: %i[index show]
    resource :'ember/solutions/folder', only: %i[index category_folders show]
    resource :"ember/search/multiquery", only: [:search_results]
    resource :'ember/admin/bot', only: [:bot_folders]
    resource :'ember/solutions/home', only: %i[summary quick_views]
    resource :'ember/solutions/draft', only: %i[index]
    resource :'ember/solutions/article_version', only: %i[index show]
    resource :"ember/dashboard/solution", only: %i[article_performance translation_summary]
  end

  export_articles do
    resource :'ember/solutions/article', only: %i[export]
  end

  manage_solutions do
    resource :'ember/admin/bot', only: %i[create_bot_folder]
    resource :'ember/solutions/folder', only: %i[create update destroy bulk_update reorder]
    resource :'ember/solutions/category', only: %i[create update destroy reorder]
    resource :'ember/company', only: %i[index]
    resource :'ember/freddy'
    resource :'ember/flow'
  end

  create_and_edit_article do
    resource :'ember/solutions/article', only: %i[create update send_for_review bulk_update]
    resource :'ember/solutions/draft', only: %i[autosave update delete_attachment destroy]
    resource :'ember/solutions/template', only: %i[index show default]
  end

  manage_solution_templates do
    resource :'ember/solutions/template', only: %i[index show create destroy update default]
  end

  approve_article do
    resource :'ember/solutions/article', only: %i[approve bulk_update]
  end

  publish_solution do
    #---start-This resource mapping is here to handle delta phase backward compatablility.
    resource :'ember/solutions/article', only: %i[reorder]
    resource :'ember/solutions/article_version', only: %i[restore]
    #---end-
  end

  delete_solution do
    resource :'ember/solutions/article', only: %i[destroy reset_ratings]
  end

  view_reports do
    resource :"ember/dashboard", only: %i[unresolved_tickets_data ticket_trends ticket_metrics]
    resource :"ember/year_in_review", only: [:share]
    resource :"ember/admin/bot", only: [:analytics, :remove_analytics_mock_data]
  end

  view_admin do
    resource :"ember/agent", only: [:complete_gdpr_acceptance]
  end

  manage_bots do
    resource :"ember/admin/bot", only: %i[new create show index update map_categories mark_completed_status_seen enable_on_portal email_channel]
    resource :"ember/portal", only: %i[show bot_prerequisites]
    resource :"ember/agent_assist", only: %i[onboard show request_demo]
  end

  view_bots do
    resource :"ember/admin/bot_feedback", only: %i[index bulk_delete bulk_map_article create_article chat_history]
    resource :"ember/admin/bot", only: %i[index show]
    resource :'ember/freddy'
    resource :'ember/flow'
  end

  manage_dashboard do
    resource :"ember/custom_dashboard", only: [:create, :update, :destroy, :widget_data_preview, :create_announcement, :end_announcement, :get_announcements, :fetch_announcement, :omni_widget_data_preview]
  end

  manage_segments do
    resource :"ember/segments/contact_filter"
    resource :"ember/segments/company_filter"
  end

  manage_proactive_outreaches do
    resource :"proactive/rule"
    resource :"proactive/simple_outreach"
  end

  view_analytics do
    resource :"ember/config", only: [:show]
  end

  view_omni_analytics do
    resource :"ember/config", only: [:show]
  end

  manage_dispatch_rules do
    resource :"admin/automation", only: [:index, :create, :show, :update, :destroy]
    resource :"api_business_hour", :only => [:index, :show]
    resource :"api_search/automation", only: [:results]
  end

  manage_supervisor_rules do
    resource :"admin/automation", only: [:index, :create, :show, :update, :destroy]
    resource :"api_business_hour", :only => [:index, :show]
    resource :"api_search/automation", only: [:results]
  end

  manage_skills do
    resource :"admin/api_skill", only: [:index, :create, :show, :update, :destroy]
  end
end
