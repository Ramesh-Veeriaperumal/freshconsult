module RabbitMq::Keys
   
  # IMPORTANT!!! - Always add new subscribers for the models at the last
  TICKET_SUBSCRIBERS            = ["auto_refresh", "reports", "search"]
  NOTE_SUBSCRIBERS              = ["auto_refresh", "reports", "search"]
  ACCOUNT_SUBSCRIBERS           = ["reports"]
  ARCHIVE_TICKET_SUBSCRIBERS    = ["reports", "search"]
  ARCHIVE_NOTE_SUBSCRIBERS      = ["search"]
  ARTICLE_SUBSCRIBERS           = ["search"]
  TOPIC_SUBSCRIBERS             = ["search"]
  POST_SUBSCRIBERS              = ["search"]
  TAG_SUBSCRIBERS               = ["search"]
  TAG_USE_SUBSCRIBERS           = ["search"]
  COMPANY_SUBSCRIBERS           = ["search"]
  USER_SUBSCRIBERS              = ["search"]

end