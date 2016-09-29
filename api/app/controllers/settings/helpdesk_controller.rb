module Settings
  class HelpdeskController < ApiApplicationController
    def index
      @item = {
        primary_language: current_account.language, 
        supported_languages: current_account.supported_languages.to_a, 
        portal_languages: current_account.portal_languages.to_a
      }
    end
  end
end