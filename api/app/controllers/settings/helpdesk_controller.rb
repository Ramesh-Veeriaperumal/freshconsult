module Settings
  class HelpdeskController < ApiApplicationController
    def index
      @item = {
        primary_language:  get_language_hash(current_account.language.to_a), 
        supported_languages:  get_language_hash(current_account.supported_languages.to_a), 
        portal_languages:  get_language_hash(current_account.portal_languages.to_a)
      }
    end

    private

      def get_language_hash(keys)
        Language.find_by_codes(keys).map { |x| [x.code, x.name] }.to_h
      end
  end
end