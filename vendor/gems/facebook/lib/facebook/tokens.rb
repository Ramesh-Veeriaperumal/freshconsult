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
        fallback_account? && !Account.current.migrate_euc_pages_to_us_enabled? ? fallback_page_tokens : default_page_tokens
      end

      def app_tokens
        fallback_account? && !Account.current.migrate_euc_pages_to_us_enabled? ? fallback_app_tokens : default_app_tokens
      end

      def fallback_account?
        FacebookFallbackConfig::ACCOUNT_IDS.include?(Account.current.id)
      end

      def default_page_tokens
        {
          app_id: FacebookConfig::PAGE_TAB_APP_ID,
          secret: FacebookConfig::PAGE_TAB_SECRET_KEY
        }
      end

      def fallback_page_tokens
        if euc_account?
          { app_id: FacebookConfig::PAGE_TAB_APP_ID_EUC, secret: FacebookConfig::PAGE_TAB_SECRET_KEY_EUC }
        else
          { app_id: FacebookConfig::PAGE_TAB_APP_ID_EU, secret: FacebookConfig::PAGE_TAB_SECRET_KEY_EU }
        end
      end

      def default_app_tokens
        {
          app_id: FacebookConfig::APP_ID,
          secret: FacebookConfig::SECRET_KEY
        }
      end

      def fallback_app_tokens
        if euc_account?
          { app_id: FacebookConfig::APP_ID_EUC, secret: FacebookConfig::SECRET_KEY_EUC }
        else
          { app_id: FacebookConfig::APP_ID_EU, secret: FacebookConfig::SECRET_KEY_EU }
        end
      end

      def euc_account?
        FacebookFallbackConfig::EUC_ACCOUNT_IDS.include?(Account.current.id)
      end
  end
end
