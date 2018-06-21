module Facebook
  class Tokens
    def initialize(page = false)
      @page = page
    end

    def tokens
      @page ? page_tokens : app_tokens
    end

    private

      def page_tokens
        fallback_account? ? fallback_page_tokens : default_page_tokens
      end

      def app_tokens
        fallback_account? ? fallback_app_tokens : default_app_tokens
      end

      def fallback_account?
        FacebookEuAccountsConfig::ACCOUNT_IDS.include?(Account.current.id)
      end

      def default_page_tokens
        {
          app_id: FacebookConfig::PAGE_TAB_APP_ID,
          secret: FacebookConfig::PAGE_TAB_SECRET_KEY
        }
      end

      def fallback_page_tokens
        {
          app_id: FacebookConfig::PAGE_TAB_APP_ID_FALLBACK,
          secret: FacebookConfig::PAGE_TAB_SECRET_KEY_FALLBACK
        }
      end

      def default_app_tokens
        {
          app_id: FacebookConfig::APP_ID,
          secret: FacebookConfig::SECRET_KEY
        }
      end

      def fallback_app_tokens
        {
          app_id: FacebookConfig::APP_ID_FALLBACK,
          secret: FacebookConfig::SECRET_KEY_FALLBACK
        }
      end
  end
end
