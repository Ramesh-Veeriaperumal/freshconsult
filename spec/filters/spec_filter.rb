class SpecFilter < SimpleCov::Filter

  FRESHFONE_FILTERS = [
    'app/controllers/freshfone/autocomplete_controller.rb',
    'app/models/freshfone_notifier.rb',
    'app/helpers/freshfone/call_history_helper.rb',
    'app/helpers/admin/freshfone/numbers_helper.rb',
    'app/helpers/admin/freshfone_helper.rb',
    'lib/freshfone/ops_notifier.rb',
    'lib/freshfone/callback_urls.rb'
  ]

  DEAD_CODE = [
    'app/controllers/anonymous/requests_controller.rb',
    'app/controllers/moderators_controller.rb',
    'app/controllers/helpdesk/ticket_issues_controller.rb',
    'app/controllers/helpdesk/issues_controller.rb',
    'app/controllers/helpdesk/tag_uses_controller.rb'
  ]

  IGNORE_LIST = [
    'app/controllers/theme/support_controller.rb',
    'app/controllers/theme_controller.rb'
  ]

  MAILER_MODELS = [
    "app/models/admin/data_import_mailer.rb", 
    "app/models/data_export_mailer.rb", 
    "app/models/email_config_notifier.rb", 
    "app/models/freshdesk_errors_mailer.rb", 
    "app/models/freshfone_notifier.rb", 
    "app/models/helpdesk/ticket_notifier.rb", 
    "app/models/helpdesk/watcher_notifier.rb", 
    "app/models/post_mailer.rb", 
    "app/models/reports/pdf_sender.rb", 
    "app/models/sla_notifier.rb", 
    "app/models/social_errors_mailer.rb", 
    "app/models/subscription_notifier.rb", 
    "app/models/topic_mailer.rb", 
    "app/models/user_notifier.rb"
  ]

  SPEC_FILTERS = [ FRESHFONE_FILTERS, DEAD_CODE, IGNORE_LIST, MAILER_MODELS ].flatten

  def matches?(src)
    SPEC_FILTERS.find {|file| src.filename =~ /#{file}/} 
  end

end