module FeatureConstants
  DISCUSSION = :forums
  TIME_ENTRIES = :timesheets
  WATCHERS = :add_watcher
  PRODUCTS = :multi_product
  TICKETS = :compose_email
  REQUESTER_WIDGET = :requester_widget
  SURVEYS = [:surveys].freeze
  SATISFACTION_RATINGS = [:surveys].freeze
  SATISFACTION_RATINGS_WITH_LINK = SATISFACTION_RATINGS | [:survey_links]
  BOT = :support_bot
  TICKET_TEMPLATES = [:ticket_templates]
  CONTACT_COMPANY_NOTES = :contact_company_notes
  CANNED_FORMS = :canned_forms
  SANDBOX = :sandbox
  TIMELINE = [:timeline].freeze
  BOT_EMAIL_CHANNEL = :bot_email_channel.freeze
  BOT_CHAT_HISTORY = :bot_chat_history.freeze
  AUTOMATION_REVAMP = :automation_revamp.freeze
  ARCHIVE_API = :archive_tickets_api
end
