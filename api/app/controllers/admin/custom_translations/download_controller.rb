class Admin::CustomTranslations::DownloadController < ApiApplicationController
  FIELDS_TO_BE_TRANSLATED = ['ticket_fields'].freeze

  PRELOAD_ASSOC = [
    :picklist_values,
    parent: [picklist_values: [
      sub_picklist_values: { sub_picklist_values: [:sub_picklist_values] }
    ]]
  ].freeze

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

  private

    def feature_name
      :custom_translations
    end

    def fetch_ticket_fields
      ticket_fields = {}

      Account.current.ticket_fields_with_nested_fields.preload(PRELOAD_ASSOC).each do |ticket_field|
        if !ticket_field.default || ['default_status', 'default_ticket_type'].include?(ticket_field.field_type)
          ticket_fields = ticket_fields.merge(ticket_field.name => ticket_field.as_api_response(:custom_translation).stringify_keys)
        end
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