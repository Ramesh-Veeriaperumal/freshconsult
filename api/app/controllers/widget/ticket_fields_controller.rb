module Widget
  class TicketFieldsController < Ember::TicketFieldsController
    include WidgetConcern
    before_filter :fetch_portal
    before_filter :set_current_language
    before_filter :set_locale
    around_filter :response_cache, only: [:index]

    # caching only with product as company field will not be visible to end user
    def response_cache_key
      key = @current_portal.main_portal ? CUSTOMER_EDITABLE_TICKET_FIELDS_FULL : CUSTOMER_EDITABLE_TICKET_FIELDS_WITHOUT_PRODUCT
      @response_cache_key ||= format(key, account_id: current_account.id, language_code: Language.current.code)
    end

    private

      # when there is a code change reset the above memcache keys for all accounts
      def scoper
        @current_portal.customer_editable_ticket_fields(true)
      end

      def validate_filter_params
        params.permit(:language, *ApiConstants::DEFAULT_INDEX_FIELDS)
        errors = [[:language, :not_included]] if params.key?(:language) && Account.current.all_languages.exclude?(params[:language])
        render_errors errors, list: Account.current.all_languages.join(', ') if errors
      end

      def set_locale
        I18n.locale = Language.current.code || I18n.default_locale
      end
  end
end
