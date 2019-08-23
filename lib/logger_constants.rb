module LoggerConstants
  # Controller action mapping to skip logs for the controller actions
  SKIP_LOGS_FOR = {
    ember_bootstrap: %w[me index account],
    ember_ticket_field: %w[index],
    ember_bootstrap_agents_group: %w[index],
    ember_freshcaller_setting: %w[index desktop_notification],
    ember_tickets_draft: %w[show_draft save_draft],
    ember_installed_application: %w[index],
    tickets_subscription: %w[watchers],
    ember_marketplace_app: %w[index],
    ember_dashboard: %w[unresolved_tickets_data ticket_trends ticket_metrics survey_info scorecard show],
    ember_ticket: %w[latest_note],
    ember_contact_field: %w[index],
    ember_company_field: %w[index],
    ember_livechat_setting: %w[index],
    time_entry: %w[ticket_time_entries],
    ember_contact: %w[activities],
    ember_company: %w[activities],
    channel_v2_ticket: %w[index show],
    channel_v2_conversation: %w[ticket_conversations],
    ember_custom_dashboard: %w[widgets_data index show],
    ember_year_in_review: %w[index],
    home: %w[index], # OLD UI ACTIONS START HERE
    support_home: %w[index],
    support_login: %w[new],
    helpdesk_inline_attachment: %w[one_hop_url],
    helpdesk_ticket: %w[index show component full_paginate prevnext latest_note save_draft status custom_search filter_options summary ticket_association activities],
    helpdesk_dashboard: %w[latest_activities index tickets_summary agent_status activity_list achievements],
    helpdesk_subscription: %w[index],
    notification_user_notification: %w[token],
    widgets_feedback_widget: %w[new create],
    user: %w[profile_image profile_image_no_blank show],
    integration_jira_issue: %w[notify],
    support_ticket: %w[show new check_email index filter close export_csv],
    support_solutions_article: %w[show hit]
  }.freeze
end
