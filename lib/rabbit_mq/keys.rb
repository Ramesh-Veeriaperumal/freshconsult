module RabbitMq::Keys

  # IMPORTANT!!! - Always add new subscribers for the models at the last
  TICKET_SUBSCRIBERS           =  ["auto_refresh", "reports", "search", "count", "activities", "marketplace_app", "collaboration"]
  NOTE_SUBSCRIBERS             =  ["auto_refresh", "reports", "search", "activities"]
  ACCOUNT_SUBSCRIBERS          =  ["reports", "activities"]
  ARCHIVE_TICKET_SUBSCRIBERS   =  ["reports", "search"]
  ARCHIVE_NOTE_SUBSCRIBERS     =  ["search"]
  ARTICLE_SUBSCRIBERS          =  ["search", "activities"]
  TOPIC_SUBSCRIBERS            =  ["search", "activities"]
  POST_SUBSCRIBERS             =  ["search", "activities"]
  TAG_SUBSCRIBERS              =  ["search", "reports"]
  TAG_USE_SUBSCRIBERS          =  ["search", "reports"]
  COMPANY_SUBSCRIBERS          =  ["search"]
  USER_SUBSCRIBERS             =  ["search", "collaboration"]
  CALLER_SUBSCRIBERS           =  ["search"]
  FORUM_CATEGORY_SUBSCRIBERS   =  ["activities"]
  FORUM_SUBSCRIBERS            =  ["activities"]
  TIME_SHEET_SUBSCRIBERS       =  ["activities"]
  CTI_CALL_SUBSCRIBERS         =  ["cti"]
end