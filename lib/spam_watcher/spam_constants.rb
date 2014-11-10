module SpamConstants
  # Spam Sorted set having the redis key sorted set and threshold for every 1 Hour window

  SPAM_WATCHER = {
    "helpdesk_tickets" => {
      "key_space" => "sw_helpdesk_tickets",
      "threshold" => 50,
      "sec_expire" => 1800
    },
    "helpdesk_notes" => {
      "key_space" => "sw_helpdesk_notes",
      "threshold" => 50,
      "sec_expire" => 1800
    },
    "solution_articles" => {
      "key_space" => "sw_solution_articles",
      "threshold" => 10,
      "sec_expire" => 21600
    },
    "posts" => {
      "key_space" => "sw_posts",
      "threshold" => 100,
      "sec_expire" => 21600
    }

  }

  # push all the ban keys to spam watcher queue for processing later
  SPAM_WATCHER_BAN_KEY = "spam_watcher_queue"

  SPAM_TIMEOUT = 2

end
