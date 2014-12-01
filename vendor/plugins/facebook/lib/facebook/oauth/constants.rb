module Facebook
  module Oauth
    module Constants
      PERMISSION = [
        "public_profile",
        "manage_pages",
        "email",
        "read_stream",
        "publish_stream",
        "read_page_mailboxes"
      ]

      PAGE_TAB_PERMISSION = [
        "public_profile",
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
