module RabbitMq::Keys

  # IMPORTANT!!! - Always add new subscribers for the models at the last
  TICKET_SUBSCRIBERS           =  ["auto_refresh", "reports", "search", "count", "activities", "marketplace_app", "collaboration", "iris", "export"]
  NOTE_SUBSCRIBERS             =  ["auto_refresh", "reports", "search", "activities", "iris"]
  ACCOUNT_SUBSCRIBERS          =  ["reports", "activities", "iris"]
  ARCHIVE_TICKET_SUBSCRIBERS   =  ["reports", "search", "iris"]
  ARCHIVE_NOTE_SUBSCRIBERS     =  ["search"]
  ARTICLE_SUBSCRIBERS          =  ["search", "activities"]
  TOPIC_SUBSCRIBERS            =  ["search", "activities"]
  POST_SUBSCRIBERS             =  ["search", "activities"]
  TAG_SUBSCRIBERS              =  ["search", "reports"]
  TAG_USE_SUBSCRIBERS          =  ["search", "reports"]
  COMPANY_SUBSCRIBERS          =  ["search", "export"]
  USER_SUBSCRIBERS             =  ["search", "collaboration", "iris", "export"]
  CALLER_SUBSCRIBERS           =  ["search"]
  FORUM_CATEGORY_SUBSCRIBERS   =  ["activities"]
  FORUM_SUBSCRIBERS            =  ["activities"]
  TIME_SHEET_SUBSCRIBERS       =  ["activities"]
  CTI_CALL_SUBSCRIBERS         =  ["cti"]
end