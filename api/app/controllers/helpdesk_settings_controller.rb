class HelpdeskSettingsController < ApiApplicationController
  def index
    load_objects
    @item = { primary_language: get_language_hash(current_account.language) }
    @item.merge!(supported_languages: get_language_hash(@helpdesk_settings.supported_languages))
    if @helpdesk_settings.additional_settings[:portal_languages]
      @item.merge!(portal_languages: get_language_hash(@helpdesk_settings.additional_settings[:portal_languages]))
    else
      @item.merge!(portal_languages: {})
    end
  end

  private

    def load_objects(item = scoper)
      @helpdesk_settings = item
    end

    def get_language_hash(keys)
      Language.all.map { |x| [x.code, x.name] }.to_h.slice(*keys)
    end

    def scoper
      current_account.account_additional_settings
    end
end
