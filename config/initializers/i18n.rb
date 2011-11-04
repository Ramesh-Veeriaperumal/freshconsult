module I18n

    def self.name_for_locale(locale)
        begin
          I18n.backend.translate(locale, "meta.language_name")
        rescue I18n::MissingTranslationData
          locale.to_s
        end
     end
    
      def self.available_locales_with_name
         locales = I18n.available_locales.inject({}) {|ha, (k, v)| ha[I18n.name_for_locale(k)] = k ; ha}.sort_by {|p,q| p.to_s }
      end
    
    

end

