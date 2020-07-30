class Admin::CustomTranslations::DownloadController < ApiApplicationController
  FIELDS_TO_BE_TRANSLATED = ['ticket_fields'].freeze

  PRELOAD_ASSOC = [
    :picklist_values,
    parent: [picklist_values: [
      sub_picklist_values: { sub_picklist_values: [:sub_picklist_values] }
    ]]
  ].freeze

  INVALID_TICKET_FIELDS = ['default_internal_group', 'default_internal_agent', 'default_source'].freeze

  def scoper; end

  def load_object; end

  # Download language translation file for the given fields (custom)
  def primary
    primary_lang = Account.current.language
    fields_data = {}

    FIELDS_TO_BE_TRANSLATED.each do |field|
      fields_data[field] = safe_send("fetch_#{field}")
    end

    translation_file = { primary_lang => { 'custom_translations' => fields_data } }

    respond_to do |format|
      response.headers['Content-Disposition'] = 'attachment; filename="primary.yml"'
      format.json { render text: translation_file.psych_to_yaml, content_type: 'text/plain' }
    end
  end

  def secondary
    secondary_lang = params[:id]

    if secondary_lang == Account.current.language
      primary
      return
    end

    return unless validate_secondary_lang(secondary_lang)

    fields_data = {}
    FIELDS_TO_BE_TRANSLATED.each do |field|
      fields_data[field] = safe_send("fetch_#{field}_translations", secondary_lang)
    end

    translation_file = { secondary_lang => { 'custom_translations' => fields_data } }

    respond_to do |format|
      response.headers['Content-Disposition'] = "attachment; filename=#{secondary_lang}.yml"
      format.json { render text: translation_file.psych_to_yaml, content_type: 'text/plain' }
    end
  end

  private

    def feature_name
      :custom_translations
    end

    def validate_secondary_lang(lang)
      permitted_language_list = Account.current.supported_languages

      if permitted_language_list.empty?
        errors = [[:language, :empty_supported_language]]
        render_errors errors
        return
      end

      if Language.find_by_code(lang).nil? || !permitted_language_list.include?(lang)
        errors = [[:language, :unsupported_language]]
        render_errors errors, language_code: lang, list: permitted_language_list.sort.join(', ')
      end
      permitted_language_list.include?(lang)
    end

    def preload_assoc(lang)
      preload = PRELOAD_ASSOC.dup
      preload << "#{lang}_translation".to_sym << { nested_ticket_fields: { ticket_field: ["#{lang}_translation".to_sym] } }
    end

    def invalid_ticket_fields
      Account.current.ticket_source_revamp_enabled? ? ['default_internal_group', 'default_internal_agent'] : INVALID_TICKET_FIELDS
    end

    def fetch_ticket_fields
      ticket_fields = {}

      Account.current.ticket_fields_with_nested_fields.preload(PRELOAD_ASSOC).each do |ticket_field|
        ticket_fields = ticket_fields.merge(ticket_field.name => ticket_field.as_api_response(:custom_translation).stringify_keys) unless invalid_ticket_fields.include?(ticket_field.field_type)
      end

      ticket_fields
    end

    def fetch_ticket_fields_translations(language_id)
      ticket_fields = {}
      lang = Language.find_by_code(language_id).to_key

      Account.current.ticket_fields_with_nested_fields.preload(preload_assoc(lang)).each do |x|
        ticket_fields = ticket_fields.merge(x.name => x.as_api_response(:custom_translation_secondary, lang: lang).stringify_keys) unless invalid_ticket_fields.include?(x.field_type)
      end

      ticket_fields
    end

    def fetch_contact_fields
      # TBD
    end

    def fetch_company_fields
      # TBD
    end

    def fetch_customer_surveys
      # TBD
    end
end
