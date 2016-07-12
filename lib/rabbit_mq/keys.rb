module RabbitMq::Keys

  # IMPORTANT!!! - Always add new subscribers for the models at the last
  TICKET_SUBSCRIBERS           =  ["auto_refresh", "reports", "search", "count", "activities"]
  NOTE_SUBSCRIBERS             =  ["auto_refresh", "reports", "search", "activities"]
  ACCOUNT_SUBSCRIBERS          =  ["reports", "activities"]
  ARCHIVE_TICKET_SUBSCRIBERS   =  ["reports", "search", "activities"]
  ARCHIVE_NOTE_SUBSCRIBERS     =  ["search"]
  ARTICLE_SUBSCRIBERS          =  ["search", "activities"]
  TOPIC_SUBSCRIBERS            =  ["search", "activities"]
  POST_SUBSCRIBERS             =  ["search", "activities"]
  TAG_SUBSCRIBERS              =  ["search"]
  TAG_USE_SUBSCRIBERS          =  ["search", "count"]
  COMPANY_SUBSCRIBERS          =  ["search"]
  USER_SUBSCRIBERS             =  ["search"]
  FORUM_CATEGORY_SUBSCRIBERS   =  ["activities"]
  FORUM_SUBSCRIBERS            =  ["activities"]
  TIME_SHEET_SUBSCRIBERS       =  ["activities"]
  
end