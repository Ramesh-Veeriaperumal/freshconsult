module Facebook
  module Oauth
    module Constants
      PERMISSION = [
        "public_profile",
        "manage_pages",
        "email",
        "publish_actions",
        "publish_pages",
        "read_page_mailboxes"
      ]

      PAGE_TAB_PERMISSION = [
        "public_profile",
        "user_likes",
        "email"
      ]

      URL = "https://www.facebook.com/dialog/oauth"
      
      PAGE_TAB_URL = "https://www.facebook.com/dialog/pagetab"

      REALTIME = "realtime"

      PAGE_TAB = "page_tab"

      DEFAULT_PAGE_IMG_URL = "http://profile.ak.fbcdn.net/static-ak/rsrc.php/v1/yG/r/2lIfT16jRCO.jpg"

    end
  end
end
