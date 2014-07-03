module Facebook
  module Oauth
    module Constants
      PERMISSION = [
        "manage_pages",
        "offline_access",
        "email",
        "read_stream",
        "publish_stream",
        "manage_notifications",
        "read_mailbox",
        "read_page_mailboxes",
        "read_insights"
      ]

      PAGE_TAB_PERMISSION = [
        "user_likes",
        "email"
      ]

      URL = "https://www.facebook.com/dialog/oauth"

      REALTIME = "realtime"

      PAGE_TAB = "page_tab"

      DEFAULT_PAGE_IMG_URL = "http://profile.ak.fbcdn.net/static-ak/rsrc.php/v1/yG/r/2lIfT16jRCO.jpg"

    end
  end
end