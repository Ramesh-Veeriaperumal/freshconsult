class SpecFilter < SimpleCov::Filter

  DEAD_CODE = [
    'app/controllers/anonymous/requests_controller.rb',
    'app/controllers/moderators_controller.rb',
    'app/controllers/helpdesk/ticket_issues_controller.rb',
    'app/controllers/helpdesk/issues_controller.rb',
    'app/controllers/helpdesk/tag_uses_controller.rb',
    'app/controllers/social/twitter_handles_controller.rb',
    'app/models/helpdesk/issue.rb',
    'app/models/flexifield_picklist_val.rb'
  ]

  IGNORE_LIST = [
    'app/controllers/theme/support_controller.rb',
    'app/controllers/theme_controller.rb',
    'lib/aws_wrapper/dynamo_db.rb',
    'lib/aws_wrapper/sqs.rb',
    'lib/two_factor_authentication.rb',
    'app/controllers/helpdesk/authorizations_controller.rb',
    'lib/ruby_bridge.rb', 
    'lib/faye/agent_collision.rb', 
    'lib/guid.rb', 
    'lib/admin_controller_methods.rb',
    'app/models/admin_user.rb',
    'app/models/conversion_metric.rb'
  ]

  MAILER_MODELS = [
    'app/models/admin/data_import_mailer.rb', 
    'app/models/data_export_mailer.rb', 
    'app/models/email_config_notifier.rb', 
    'app/models/freshdesk_errors_mailer.rb', 
    'app/models/freshfone_notifier.rb', 
    'app/models/helpdesk/ticket_notifier.rb', 
    'app/models/helpdesk/watcher_notifier.rb', 
    'app/models/post_mailer.rb', 
    'app/models/reports/pdf_sender.rb', 
    'app/models/sla_notifier.rb', 
    'app/models/social_errors_mailer.rb', 
    'app/models/subscription_notifier.rb', 
    'app/models/topic_mailer.rb', 
    'app/models/user_notifier.rb'
  ]

  BILLING_MODELS = [
    'app/models/subscription_event.rb',
    'app/models/subscription_notifier.rb',
    'app/models/subscription_payment.rb'
  ]

  TICKET_WEEKLY_TABLE_MODELS = [
    'lib/helpdesk/mysql/dynamic_table.rb',
    'app/models/helpdesk/note_body_weekly.rb',
    'app/models/helpdesk/ticket_body_weekly.rb'
  ]


  SPEC_FILTERS = [ DEAD_CODE, IGNORE_LIST, MAILER_MODELS, BILLING_MODELS,
                    TICKET_WEEKLY_TABLE_MODELS ].flatten

  def matches?(src)
    SPEC_FILTERS.find {|file| src.filename =~ /#{file}/} 
  end

end