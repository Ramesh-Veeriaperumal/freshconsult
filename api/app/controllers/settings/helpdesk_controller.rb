module Settings
  class HelpdeskController < ApiApplicationController
    include HelperConcern

    def index
      @item = {
        primary_language: current_account.language,
        supported_languages: current_account.supported_languages.to_a,
        portal_languages: current_account.portal_languages.to_a
      }
    end

    def update
      @item.main_portal.language = cname_params['primary_language'] if cname_params['primary_language'].present? && !@item.features_included?(:enable_multilingual)
      @item.account_additional_settings.supported_language_setter(cname_params['supported_languages']) unless cname_params['supported_languages'].nil?
      @item.account_additional_settings.portal_language_setter(cname_params['portal_languages']) unless cname_params['portal_languages'].nil?
      @item.save ? Account.current.check_and_enable_multilingual_feature : render_errors(@item.errors)
    end

    private

      def validate_params
        validate_body_params(@item, cname_params)
      end

      def constants_class
        'Settings::HelpdeskConstants'.freeze
      end

      def load_object
        @item = current_account
      end

      def sanitize_params
        ['supported_languages', 'portal_languages'].each do |languages|
          cname_params[languages] = (cname_params[languages] && cname_params[languages].uniq)
        end
        not_supported = (portal_languages || []) - supported_languages
        cname_params['portal_languages'] = (portal_languages || []) - not_supported if not_supported.present?
      end

      def supported_languages
        @supported_languages ||= cname_params['supported_languages'] || @item.supported_languages
      end

      def portal_languages
        @portal_languages ||= cname_params['portal_languages'] || @item.portal_languages
      end

      def set_root_key
        response.api_root_key = api_root_key.singularize
      end
  end
end
