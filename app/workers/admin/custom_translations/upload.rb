# Worker to validate and store the custom translations in the YML file uploaded by the user
class Admin::CustomTranslations::Upload < BaseWorker
  sidekiq_options queue: :custom_translations_upload_queue, retry: 0,  failures: :exhausted

  PRELOAD_ASSOC = [
    :picklist_values,
    parent:
      [picklist_values:
        [
          sub_picklist_values: { sub_picklist_values: [:sub_picklist_values] }
        ]]
  ].freeze

  FIELD_MAPPING = {
    'ticket_fields' => 'ticket_fields_with_nested_fields'
  }.freeze

  CHOICE_MAPPING = {
    'ticket_fields' => 'fetch_custom_field_choices'
  }.freeze

  FIELDS_WITH_CHOICES = ['nested_field', 'custom_dropdown', 'default_ticket_type', 'default_status'].freeze

  VALID_KEYS = ['label', 'customer_label', 'choices'].freeze

  def perform(file_path, language_code)
    translation_hash = load_yml(file_path)
    @language = Language.find_by_code(language_code)
    sanitize_yml(translation_hash)
  rescue => exception
    Rails.logger.error("Error in custom translations upload :: Account id: #{Account.current.id} \nException : #{exception} \n#{exception.backtrace.to_a.join("\n")}")
    NewRelic::Agent.notice_error(exception, description: "Error in custom translations upload :: \nAccount id: #{Account.current.id} \nException : #{exception} \n#{exception.backtrace.to_a.join("\n")}")
  end

  def load_yml(file_path)
    translation_file =  AwsWrapper::S3Object.read(file_path, S3_CONFIG[:bucket])
    translation_hash = YAML.load(translation_file, safe: true)
    translation_hash
  end

  def sanitize_yml(yml_hash)
    current_account = Account.current
    custom_translations_yml = yml_hash[@language.code]['custom_translations']
    FIELD_MAPPING.each_key do |field_type|
      field_translations = custom_translations_yml[field_type]
      field_objects = current_account.safe_send(FIELD_MAPPING[field_type]).preload(preload_assoc)
      ticket_field_names = []
      field_objects.map { |ticket_object| ticket_field_names.append(ticket_object.name) }
      field_translations.each do |field, translations|
        field_translations.delete(field) && next unless ticket_field_names.include?(CGI.escapeHTML(field))
        field_object = field_objects[ticket_field_names.find_index(CGI.escapeHTML(field))]
        translations = sanitize_translations(field_object, field_type, translations)
        field_translations.delete(field) && next if translations == -1
        if field_type == 'ticket_fields' && field_object.nested_field?
          field_object, translations = sanitize_nested_fields(field_object, field_type, field_translations)
          translations = compare_and_merge(field_object, translations)
        end
        create_translation(field_object, translations)
      end
    end
  end

  def sanitize_nested_fields(field_object, field_type, field_translations)
    parent_field_object = (field_object.level.nil? ? field_object : field_object.parent)
    child_field_objects = parent_field_object.child_levels
    nested_translations = []
    child_field_objects.each do |child_object|
      child_translation = sanitize_translations(child_object, field_type, field_translations[child_object.name])
      nested_translations << [child_object.level, child_translation] unless child_translation == -1
      field_translations.delete(child_object.name)
    end
    parent_translation = sanitize_translations(parent_field_object, field_type, field_translations[parent_field_object.name])
    nested_translations << [nil, parent_translation] unless parent_translation == -1
    field_translations.delete(parent_field_object.name)
    translations = merge_nested_translations(nested_translations)
    [parent_field_object, translations]
  end

  def merge_nested_translations(nested_translations)
    translations = { 'choices' => {} }
    nested_translations.each do |child_translation|
      suffix = (child_translation[0].nil? ? '' : '_' + child_translation[0].to_s)
      translations['choices'] = translations['choices'].merge(child_translation[1]['choices'].nil? ? {} : child_translation[1]['choices'])
      translations['label' + suffix] = child_translation[1]['label']
      translations['customer_label' + suffix] = child_translation[1]['customer_label']
    end
    translations
  end

  def create_translation(field_object, translations)
    custom_translation = field_object.safe_send(language_translation)
    if custom_translation.nil?
      field_object.safe_send('build_' + language_translation, translations: translations).save!
    else
      custom_translation.update_attribute(:translations, translations)
    end
  end

  def sanitize_translations(field_object, field_type, translations)
    return -1 if translations.nil?

    translations.slice!(*VALID_KEYS)
    current_account = Account.current
    choice_regex = /(choice_[0-9]+)/
    translations.delete('choices') unless FIELDS_WITH_CHOICES.include?(field_object.field_type)
    field_choices = field_object.safe_send(CHOICE_MAPPING[field_type]).map { |choice| Integer(choice[0].slice(/[0-9]+/)) }
    translations['choices'].each do |key, value|
      translations['choices'].delete(key) && next unless (key.is_a?(String) || key.nil?) && !choice_regex.match(key).nil?
      picklist_id = Integer(key.slice(/[0-9]+/))
      translations['choices'].delete(key) && next unless field_choices.include? picklist_id
    end
    translations = compare_and_merge(field_object, translations) unless field_object.nested_field?
    translations
  end

  def compare_and_merge(field_object, translations)
    field_object = field_object.parent unless field_object.level.nil?
    translations.slice!('customer_label') if field_object.only_customer_label_field?
    existing_translation = field_object.safe_send(language_translation)
    if existing_translation.nil?
      translations.delete_if { |key, value| value.nil? || value == '' }
      translations['choices'].delete_if { |key, value| value.nil? || value == '' } if translations['choices'].is_a? Hash
      return translations
    end
    existing_translation = existing_translation.translations
    new_translation = existing_translation.merge(translations)
    new_translation.delete_if { |key, value| value.nil? || value == '' }
    if FIELDS_WITH_CHOICES.include?(field_object.field_type) && !translations['choices'].nil?
      choices_merge = (existing_translation['choices'].nil? ? {} : existing_translation['choices']).merge(translations['choices'])
      choices_merge.delete_if { |key, value| value.nil? || value == '' }
      new_translation['choices'] = choices_merge
    end
    new_translation
  end

  def language_translation
    "#{@language.to_key}_translation"
  end

  def preload_assoc
    preload = PRELOAD_ASSOC.dup
    preload << language_translation.to_sym << { nested_ticket_fields: { ticket_field: [language_translation.to_sym] } }
  end
end
