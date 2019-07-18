module CustomTranslations::Associations
  extend ActiveSupport::Concern
  included do |base|
    has_many :custom_translations, class_name: 'CustomTranslation', as: :translatable, dependent: :destroy

    Language.all.each do |lang|
      has_one :"#{lang.to_key}_translation",
      conditions: proc { { language_id: lang.id, account_id: Account.current.id } },
      class_name: 'CustomTranslation',
      as: :translatable
    end

    def translation_record(language = current_language)
      @translation_record ||= custom_translations_feature_check(language) ? safe_send("#{language.to_key}_translation") : nil
    end

    private

      def current_language
        Language.find_by_code(I18n.locale)
      end

      def custom_translations_feature_check(language = current_language)
        Account.current.custom_translations_enabled? && Account.current.supported_languages.include?(language.code)
      end
  end
end
