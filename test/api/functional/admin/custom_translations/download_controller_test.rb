require_relative '../../../test_helper'
class Admin::CustomTranslations::DownloadControllerTest < ActionController::TestCase
  include TicketFieldsTestHelper
  CHOICES = ['Get Smart', 'Pursuit of Happiness', 'Armaggedon'].freeze
  DEFAULT_FIELDS = ['requester', 'subject', 'priority', 'group', 'agent', 'product', 'description', 'company'].freeze
  INVALID_TICKET_FIELDS = ['default_internal_group', 'default_internal_agent', 'default_source'].freeze

  def setup
    super
    set_secondary_language
  end

  def stub_for_custom_translations
    Account.current.add_feature(:custom_translations)
  end

  def unstub_for_custom_translations
    Account.current.revoke_feature(:custom_translations)
  end

  def set_secondary_language
    additional = Account.current.account_additional_settings
    additional.supported_languages = ['fr', 'de', 'zh-CN']
    additional.save
  end

  def create_custom_translations(field, lang)
    language_id = Language.find_by_code(lang).id
    label = field.as_api_response(:custom_translation)[:label] + '_' + Faker::Lorem.word unless DEFAULT_FIELDS.include?(field.name)
    customer_label = field.as_api_response(:custom_translation)[:customer_label] + '_' + Faker::Lorem.word

    if field.field_type == 'nested_field' && field.parent_id.present?
      translated_data = { "label_#{field.level}" => label, "customer_label_#{field.level}" => customer_label }
    else
      translated_data = { 'label' => label, 'customer_label' => customer_label }
    end

    if field.as_api_response(:custom_translation)[:choices].present?
      choices = Hash[field.as_api_response(:custom_translation)[:choices].map { |x, y| [x, y + '_' + Faker::Lorem.word] }]
      translated_data = translated_data.merge('choices' => choices)
    end

    if field.field_type == 'nested_field' && field.parent_id.present?
      field = field.parent
      tmp_translations = field.safe_send("#{lang}_translation").try(:translations)
      translated_data = tmp_translations.merge(translated_data)
      translated_data['choices'] = translated_data['choices'].merge(tmp_translations['choices'])
    end

    translated_data.slice!('customer_label') if DEFAULT_FIELDS.include?(field.name)
    if field.custom_translations.present?
      custom_translation_record = field.safe_send("#{lang}_translation")
      custom_translation_record.translations = translated_data
      custom_translation_record.save
    else
      field.custom_translations.create(language_id: language_id, translations: translated_data)
    end
  end

  def test_primary_custom_ticket_fields_count
    stub_for_custom_translations
    get :primary, construct_params({})
    assert_response 200
    primary_lang = Account.current.language
    ticket_fields = YAML.load(response.body)[primary_lang]['custom_translations']['ticket_fields'].count
    acc_tkt_fields = Account.current.ticket_fields_with_nested_fields.where('field_type not in (?)', INVALID_TICKET_FIELDS).count
    assert_equal acc_tkt_fields, ticket_fields
  ensure
    unstub_for_custom_translations
  end

  def test_primary_ticket_field_type
    stub_for_custom_translations
    get :primary, construct_params({})
    assert_response 200
    primary_lang = Account.current.language
    ticket_fields = YAML.load(response.body)[primary_lang]['custom_translations']['ticket_fields']
    assert ticket_fields.include?('ticket_type')
  ensure
    unstub_for_custom_translations
  end

  def test_primary_ticket_field_status
    stub_for_custom_translations
    get :primary, construct_params({})
    assert_response 200
    primary_lang = Account.current.language
    ticket_fields = YAML.load(response.body)[primary_lang]['custom_translations']['ticket_fields']
    assert ticket_fields.include?('status')
  ensure
    unstub_for_custom_translations
  end

  def test_primary_custom_dropdown
    stub_for_custom_translations
    custom_dropdown = create_custom_field_dropdown('test_custom_dropdown', CHOICES)
    get :primary, construct_params({})
    assert_response 200
    primary_lang = Account.current.language
    ticket_fields = YAML.load(response.body)[primary_lang]['custom_translations']['ticket_fields']
    assert ticket_fields.include?(custom_dropdown.name)
  ensure
    unstub_for_custom_translations
  end

  def test_primary_custom_field_number
    stub_for_custom_translations
    field = create_custom_field('test_custom_number', 'number')
    get :primary, construct_params({})
    assert_response 200
    primary_lang = Account.current.language
    ticket_fields = YAML.load(response.body)[primary_lang]['custom_translations']['ticket_fields']
    assert ticket_fields.include?(field.name)
  ensure
    unstub_for_custom_translations
  end

  def test_primary_custom_field_checkbox
    stub_for_custom_translations
    field = create_custom_field('test_custom_checkbox', 'checkbox')
    get :primary, construct_params({})
    assert_response 200
    primary_lang = Account.current.language
    ticket_fields = YAML.load(response.body)[primary_lang]['custom_translations']['ticket_fields']
    assert ticket_fields.include?(field.name)
  ensure
    unstub_for_custom_translations
  end

  def test_primary_custom_field_decimal
    stub_for_custom_translations
    field = create_custom_field('test_custom_decimal', 'decimal')
    get :primary, construct_params({})
    assert_response 200
    primary_lang = Account.current.language
    ticket_fields = YAML.load(response.body)[primary_lang]['custom_translations']['ticket_fields']
    assert ticket_fields.include?(field.name)
  ensure
    unstub_for_custom_translations
  end

  def test_primary_custom_field_text
    stub_for_custom_translations
    field = create_custom_field('test_custom_text', 'text')
    get :primary, construct_params({})
    assert_response 200
    primary_lang = Account.current.language
    ticket_fields = YAML.load(response.body)[primary_lang]['custom_translations']['ticket_fields']
    assert ticket_fields.include?(field.name)
  ensure
    unstub_for_custom_translations
  end

  def test_primary_custom_field_paragraph
    stub_for_custom_translations
    field = create_custom_field('test_custom_paragraph', 'paragraph')
    get :primary, construct_params({})
    assert_response 200
    primary_lang = Account.current.language
    ticket_fields = YAML.load(response.body)[primary_lang]['custom_translations']['ticket_fields']
    assert ticket_fields.include?(field.name)
  ensure
    unstub_for_custom_translations
  end

  def test_primary_custom_field_date
    stub_for_custom_translations
    field = create_custom_field('test_custom_date', 'date')
    get :primary, construct_params({})
    assert_response 200
    primary_lang = Account.current.language
    ticket_fields = YAML.load(response.body)[primary_lang]['custom_translations']['ticket_fields']
    assert ticket_fields.include?(field.name)
  ensure
    unstub_for_custom_translations
  end

  def test_primary_custom_status
    stub_for_custom_translations
    status = create_custom_status
    get :primary, construct_params({})
    assert_response 200
    primary_lang = Account.current.language
    status_choices = YAML.load(response.body)[primary_lang]['custom_translations']['ticket_fields']['status']['choices']
    assert status_choices["choice_#{status.status_id}"] == status.name
  ensure
    unstub_for_custom_translations
  end

  def test_primary_custom_nested_field
    stub_for_custom_translations
    create_dependent_custom_field(%w(test_custom_country test_custom_state test_custom_city))
    get :primary, construct_params({})
    assert_response 200
    primary_lang = Account.current.language
    ticket_fields = YAML.load(response.body)[primary_lang]['custom_translations']['ticket_fields']
    assert ticket_fields.include?('test_custom_country_1')
    assert ticket_fields.include?('test_custom_state_1')
    assert ticket_fields.include?('test_custom_city_1')
  ensure
    unstub_for_custom_translations
  end

  def test_primary_custom_nested_field_choices
    stub_for_custom_translations
    nested_field = create_dependent_custom_field(%w(test_custom_country test_custom_state test_custom_city))
    nested_field_level2 = Account.current.ticket_fields_with_nested_fields.find_by_name('test_custom_state_1')
    nested_field_level3 = Account.current.ticket_fields_with_nested_fields.find_by_name('test_custom_city_1')
    get :primary, construct_params({})
    assert_response 200
    primary_lang = Account.current.language
    ticket_fields = YAML.load(response.body)[primary_lang]['custom_translations']['ticket_fields']
    assert ticket_fields['test_custom_country_1']['choices'] == nested_field.fetch_custom_field_choices
    assert ticket_fields['test_custom_state_1']['choices'] == nested_field_level2.fetch_custom_field_choices
    assert ticket_fields['test_custom_city_1']['choices'] == nested_field_level3.fetch_custom_field_choices
  ensure
    unstub_for_custom_translations
  end

  def test_primary_header
    stub_for_custom_translations
    get :primary, construct_params({})
    assert_response 200
    assert response.header.include?('Content-Disposition')
  ensure
    unstub_for_custom_translations
  end

  def test_primary_check_field_which_doesnot_have_choices
    field = Account.current.ticket_fields.find_by_name('agent')
    choices = field.fetch_custom_field_choices
    assert choices.empty?
  end

  def test_primary_change_primary_language
    stub_for_custom_translations
    Account.current.main_portal.language = 'fr'
    Account.current.main_portal.save
    get :primary, construct_params({})
    assert_response 200
    assert YAML.load(response.body)['fr'].present?
  ensure
    Account.current.main_portal.language = 'en'
    Account.current.main_portal.save
    unstub_for_custom_translations
  end

  def test_primary_file_name
    stub_for_custom_translations
    get :primary, construct_params({})
    assert_response 200
    assert response.header['Content-Disposition'].include?('primary.yml')
  ensure
    unstub_for_custom_translations
  end

  def test_secondary_file_name
    stub_for_custom_translations
    get :secondary, construct_params('id' => 'fr')
    assert_response 200
    assert response.header['Content-Disposition'].include?('fr.yml')
    assert YAML.load(response.body)['fr'].present?
  ensure
    unstub_for_custom_translations
  end

  def test_secondary_validate_supported_lang
    stub_for_custom_translations
    get :secondary, construct_params('id' => 'fr')
    assert_response 200
    get :secondary, construct_params('id' => 'ar')
    assert_response 400
  ensure
    unstub_for_custom_translations
  end

  def test_secondary_lang_with_special_chars
    stub_for_custom_translations
    get :secondary, construct_params('id' => 'zh-CN')
    assert_response 200
  ensure
    unstub_for_custom_translations
  end

  def test_secondary_with_primary_lang_code
    stub_for_custom_translations
    primary_lang = Account.current.language
    get :secondary, construct_params('id' => primary_lang)
    assert_response 200
    assert response.header['Content-Disposition'].include?('primary.yml')
  ensure
    unstub_for_custom_translations
  end

  def test_secondary_with_empty_secondary_language
    stub_for_custom_translations
    additional = Account.current.account_additional_settings
    additional.supported_languages = []
    additional.save
    primary_lang = Account.current.language
    all_lang = Language.all_codes
    all_lang.delete(primary_lang)
    get :secondary, construct_params('id' => all_lang[0])
    assert_response 400
  ensure
    unstub_for_custom_translations
    set_secondary_language
  end

  def test_secondary_custom_field_number
    stub_for_custom_translations
    field = Account.current.ticket_fields.find_by_name('test_custom_number_1')
    get :secondary, construct_params('id' => 'fr')
    assert_response 200
    response_field = YAML.load(response.body)['fr']['custom_translations']['ticket_fields']['test_custom_number_1']
    assert response_field.present?
    assert response_field['label'].empty?
    assert response_field['customer_label'].empty?
    create_custom_translations(field, 'fr')
    get :secondary, construct_params('id' => 'fr')
    assert_response 200
    response_field = YAML.load(response.body)['fr']['custom_translations']['ticket_fields']['test_custom_number_1']
    assert response_field.present?
    assert response_field['label'].present?
    assert response_field['customer_label'].present?
  ensure
    unstub_for_custom_translations
  end

  def test_secondary_custom_field_text
    stub_for_custom_translations
    field = Account.current.ticket_fields.find_by_name('test_custom_text_1')
    get :secondary, construct_params('id' => 'fr')
    assert_response 200
    response_field = YAML.load(response.body)['fr']['custom_translations']['ticket_fields']['test_custom_text_1']
    assert response_field.present?
    assert response_field['label'].empty?
    assert response_field['customer_label'].empty?
    create_custom_translations(field, 'fr')
    get :secondary, construct_params('id' => 'fr')
    assert_response 200
    response_field = YAML.load(response.body)['fr']['custom_translations']['ticket_fields']['test_custom_text_1']
    assert response_field.present?
    assert response_field['label'].present?
    assert response_field['customer_label'].present?
  ensure
    unstub_for_custom_translations
  end

  def test_secondary_custom_field_date
    stub_for_custom_translations
    field = Account.current.ticket_fields.find_by_name('test_custom_date_1')
    get :secondary, construct_params('id' => 'fr')
    assert_response 200
    response_field = YAML.load(response.body)['fr']['custom_translations']['ticket_fields']['test_custom_date_1']
    assert response_field.present?
    assert response_field['label'].empty?
    assert response_field['customer_label'].empty?
    create_custom_translations(field, 'fr')
    get :secondary, construct_params('id' => 'fr')
    assert_response 200
    response_field = YAML.load(response.body)['fr']['custom_translations']['ticket_fields']['test_custom_date_1']
    assert response_field.present?
    assert response_field['label'].present?
    assert response_field['customer_label'].present?
  ensure
    unstub_for_custom_translations
  end

  def test_secondary_custom_field_paragraph
    stub_for_custom_translations
    field = Account.current.ticket_fields.find_by_name('test_custom_paragraph_1')
    get :secondary, construct_params('id' => 'fr')
    assert_response 200
    response_field = YAML.load(response.body)['fr']['custom_translations']['ticket_fields']['test_custom_paragraph_1']
    assert response_field.present?
    assert response_field['label'].empty?
    assert response_field['customer_label'].empty?
    create_custom_translations(field, 'fr')
    get :secondary, construct_params('id' => 'fr')
    assert_response 200
    response_field = YAML.load(response.body)['fr']['custom_translations']['ticket_fields']['test_custom_paragraph_1']
    assert response_field.present?
    assert response_field['label'].present?
    assert response_field['customer_label'].present?
  ensure
    unstub_for_custom_translations
  end

  def test_secondary_custom_field_checkbox
    stub_for_custom_translations
    field = Account.current.ticket_fields.find_by_name('test_custom_checkbox_1')
    get :secondary, construct_params('id' => 'fr')
    assert_response 200
    response_field = YAML.load(response.body)['fr']['custom_translations']['ticket_fields']['test_custom_checkbox_1']
    assert response_field.present?
    assert response_field['label'].empty?
    assert response_field['customer_label'].empty?
    create_custom_translations(field, 'fr')
    get :secondary, construct_params('id' => 'fr')
    assert_response 200
    response_field = YAML.load(response.body)['fr']['custom_translations']['ticket_fields']['test_custom_checkbox_1']
    assert response_field.present?
    assert response_field['label'].present?
    assert response_field['customer_label'].present?
  ensure
    unstub_for_custom_translations
  end

  def test_secondary_custom_field_decimal
    stub_for_custom_translations
    field = Account.current.ticket_fields.find_by_name('test_custom_decimal_1')
    get :secondary, construct_params('id' => 'fr')
    assert_response 200
    response_field = YAML.load(response.body)['fr']['custom_translations']['ticket_fields']['test_custom_decimal_1']
    assert response_field.present?
    assert response_field['label'].empty?
    assert response_field['customer_label'].empty?
    create_custom_translations(field, 'fr')
    get :secondary, construct_params('id' => 'fr')
    assert_response 200
    response_field = YAML.load(response.body)['fr']['custom_translations']['ticket_fields']['test_custom_decimal_1']
    assert response_field.present?
    assert response_field['label'].present?
    assert response_field['customer_label'].present?
  ensure
    unstub_for_custom_translations
  end

  def test_secondary_custom_field_dropdown
    stub_for_custom_translations
    field = Account.current.ticket_fields.find_by_name('test_custom_dropdown_1')
    get :secondary, construct_params('id' => 'fr')
    assert_response 200
    response_field = YAML.load(response.body)['fr']['custom_translations']['ticket_fields']['test_custom_dropdown_1']
    assert response_field.present?
    assert response_field['label'].empty?
    assert response_field['customer_label'].empty?
    assert response_field['choices'].present?
    choices = response_field['choices'].map { |x, y| y }
    assert choices.all?(&:blank?)
    create_custom_translations(field, 'fr')
    get :secondary, construct_params('id' => 'fr')
    assert_response 200
    response_field = YAML.load(response.body)['fr']['custom_translations']['ticket_fields']['test_custom_dropdown_1']
    assert response_field.present?
    assert response_field['label'].present?
    assert response_field['customer_label'].present?
    assert response_field['choices'].present?
    ch = field.fetch_custom_field_choices
    assert (response_field['choices'].all? { |x, y| y.include?(ch[x]) })
  ensure
    unstub_for_custom_translations
  end

  def test_secondary_custom_field_nested_level1
    stub_for_custom_translations
    field = Account.current.ticket_fields.find_by_name('test_custom_country_1')
    get :secondary, construct_params('id' => 'fr')
    assert_response 200
    response_field = YAML.load(response.body)['fr']['custom_translations']['ticket_fields']['test_custom_country_1']
    assert response_field.present?
    assert response_field['label'].empty?
    assert response_field['customer_label'].empty?
    assert response_field['choices'].present?
    choices = response_field['choices'].map { |x, y| y }
    assert choices.all?(&:blank?)
    create_custom_translations(field, 'fr')
    get :secondary, construct_params('id' => 'fr')
    assert_response 200
    response_field = YAML.load(response.body)['fr']['custom_translations']['ticket_fields']['test_custom_country_1']
    assert response_field.present?
    assert response_field['label'].present?
    assert response_field['customer_label'].present?
    assert response_field['choices'].present?
    ch = field.fetch_custom_field_choices
    assert (response_field['choices'].all? { |x, y| y.include?(ch[x]) })
  ensure
    unstub_for_custom_translations
  end

  def test_secondary_custom_field_nested_level2
    stub_for_custom_translations
    field = Account.current.ticket_fields_with_nested_fields.find_by_name('test_custom_state_1')
    get :secondary, construct_params('id' => 'fr')
    assert_response 200
    response_field = YAML.load(response.body)['fr']['custom_translations']['ticket_fields']['test_custom_state_1']
    assert response_field.present?
    assert response_field['label'].empty?
    assert response_field['customer_label'].empty?
    assert response_field['choices'].present?
    choices = response_field['choices'].map { |x, y| y }
    assert choices.all?(&:blank?)
    create_custom_translations(field, 'fr')
    get :secondary, construct_params('id' => 'fr')
    assert_response 200
    response_field = YAML.load(response.body)['fr']['custom_translations']['ticket_fields']['test_custom_state_1']
    assert response_field.present?
    assert response_field['label'].present?
    assert response_field['customer_label'].present?
    assert response_field['choices'].present?
    ch = field.fetch_custom_field_choices
    assert (response_field['choices'].all? { |x, y| y.include?(ch[x]) })
  ensure
    unstub_for_custom_translations
  end

  def test_secondary_custom_field_nested_level3
    stub_for_custom_translations
    field = Account.current.ticket_fields_with_nested_fields.find_by_name('test_custom_city_1')
    get :secondary, construct_params('id' => 'fr')
    assert_response 200
    response_field = YAML.load(response.body)['fr']['custom_translations']['ticket_fields']['test_custom_city_1']
    assert response_field.present?
    assert response_field['label'].empty?
    assert response_field['customer_label'].empty?
    assert response_field['choices'].present?
    choices = response_field['choices'].map { |x, y| y }
    assert choices.all?(&:blank?)
    create_custom_translations(field, 'fr')
    get :secondary, construct_params('id' => 'fr')
    assert_response 200
    response_field = YAML.load(response.body)['fr']['custom_translations']['ticket_fields']['test_custom_city_1']
    assert response_field.present?
    assert response_field['label'].present?
    assert response_field['customer_label'].present?
    assert response_field['choices'].present?
    ch = field.fetch_custom_field_choices
    assert (response_field['choices'].all? { |x, y| y.include?(ch[x]) })
  ensure
    unstub_for_custom_translations
  end

  def test_secondary_custom_field_ticket_type
    stub_for_custom_translations
    field = Account.current.ticket_fields.find_by_name('ticket_type')
    get :secondary, construct_params('id' => 'fr')
    assert_response 200
    response_field = YAML.load(response.body)['fr']['custom_translations']['ticket_fields']['ticket_type']
    assert response_field.present?
    assert response_field['label'].empty?
    assert response_field['customer_label'].empty?
    choices = response_field['choices'].map { |x, y| y }
    assert choices.all?(&:blank?)
    create_custom_translations(field, 'fr')
    get :secondary, construct_params('id' => 'fr')
    assert_response 200
    response_field = YAML.load(response.body)['fr']['custom_translations']['ticket_fields']['ticket_type']
    assert response_field.present?
    assert response_field['label'].present?
    assert response_field['customer_label'].present?
    assert response_field['choices'].present?
    ch = field.fetch_custom_field_choices
    assert (response_field['choices'].all? { |x, y| y.include?(ch[x]) })
  ensure
    unstub_for_custom_translations
  end

  def test_secondary_custom_field_status
    stub_for_custom_translations
    field = Account.current.ticket_fields.find_by_name('status')
    get :secondary, construct_params('id' => 'fr')
    assert_response 200
    response_field = YAML.load(response.body)['fr']['custom_translations']['ticket_fields']['status']
    assert response_field.present?
    assert response_field['label'].empty?
    assert response_field['customer_label'].empty?
    choices = response_field['choices'].map { |x, y| y }
    assert choices.all?(&:blank?)
    create_custom_translations(field, 'fr')
    get :secondary, construct_params('id' => 'fr')
    assert_response 200
    response_field = YAML.load(response.body)['fr']['custom_translations']['ticket_fields']['status']
    assert response_field.present?
    assert response_field['label'].present?
    assert response_field['customer_label'].present?
    assert response_field['choices'].present?
    ch = field.fetch_custom_field_choices
    assert (response_field['choices'].all? { |x, y| y.include?(ch[x]) })
  ensure
    unstub_for_custom_translations
  end

  DEFAULT_FIELDS.map do |field|
    define_method "test_primary_#{field}" do
      stub_for_custom_translations
      db_field = Account.current.ticket_fields.find_by_name(field)
      get :primary, construct_params({})
      assert_response 200
      response_field = Psych.safe_load(response.body)['en']['custom_translations']['ticket_fields'][field]
      refute_empty response_field
      assert_nil response_field['label']
      assert_equal response_field['customer_label'], db_field.label_in_portal
      assert_nil response_field['choices']
      unstub_for_custom_translations
    end

    define_method "test_secondary_without_translation_#{field}" do
      stub_for_custom_translations
      get :secondary, construct_params('id' => 'fr')
      assert_response 200
      response_field = Psych.safe_load(response.body)['fr']['custom_translations']['ticket_fields'][field]
      refute_empty response_field
      assert_nil response_field['label']
      assert_empty response_field['customer_label']
      assert_nil response_field['choices']
      unstub_for_custom_translations
    end

    define_method "test_secondary_with_translation_#{field}" do
      stub_for_custom_translations
      db_field = Account.current.ticket_fields.find_by_name(field)
      translations = create_custom_translations(db_field, 'fr')
      get :secondary, construct_params('id' => 'fr')
      assert_response 200
      response_field = Psych.safe_load(response.body)['fr']['custom_translations']['ticket_fields'][field]
      refute_empty response_field
      assert_nil response_field['label']
      assert_equal response_field['customer_label'], translations.translations['customer_label']
      assert_nil response_field['choices']
      unstub_for_custom_translations
      translations.destroy
    end
  end
end