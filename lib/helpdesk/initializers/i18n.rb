module I18n
    #the below languages have dummy locale files in config
    #paperclip gem introduces these locales causing the order of available locales to be messed up. 
    #This is a hack - Rex
    IGNORE_LANGUAGES = [:"zh-HK", :ja, :ru, :no].freeze

    def self.name_for_locale(locale)
        begin
          I18n.backend.translate(locale, "meta.language_name")
        rescue I18n::MissingTranslationData
          locale.to_s
        end
     end

     def self.available_locales_with_name
        @locales_with_name ||= begin 
          available_locales = Rails.env.production? ? (I18n.available_locales - Language::TEST_LANGUAGES - IGNORE_LANGUAGES) : I18n.available_locales
          available_locales.inject({}) {|ha, (k, v)| ha[I18n.name_for_locale(k)] = k ; ha}.sort_by {|p,q| p.to_s }
        end
     end
end

