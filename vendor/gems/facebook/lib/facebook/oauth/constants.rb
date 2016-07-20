module Facebook
  module Oauth
    module Constants
      PAGE_PERMISSIONS = [
        "public_profile",
        "manage_pages",
        "email",
        "publish_actions",
        "publish_pages",
        "read_page_mailboxes",
        "pages_messaging"
      ]

      PAGE_TAB_PERMISSIONS = [
        "public_profile",
        "user_likes",
        "email"
      ]

      FB_AUTH_DIALOG_URL   = "https://www.facebook.com/dialog/oauth"
      
      PAGE_TAB_URL         = "https://www.facebook.com/dialog/pagetab"

      REALTIME             = "realtime"

      PAGE_TAB             = "page_tab"
      
      PAGE_FIELDS          = ["id", "picture", "link", "name"]

      DEFAULT_PAGE_IMG_URL = "http://profile.ak.fbcdn.net/static-ak/rsrc.php/v1/yG/r/2lIfT16jRCO.jpg"

    end
  end
end
