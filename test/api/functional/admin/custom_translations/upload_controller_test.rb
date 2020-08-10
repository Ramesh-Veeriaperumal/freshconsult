require_relative '../../../test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

class Admin::CustomTranslations::UploadControllerTest < ActionController::TestCase
  include TicketFieldsTestHelper

  TICKET_FIELDS_WITH_CHOICES = ['nested_field', 'custom_dropdown', 'default_ticket_type', 'default_status', 'default_source'].freeze

  FIELD_MAPPING = {
    'Helpdesk::TicketField' => 'ticket_fields_with_nested_fields'
  }.freeze

  CHOICE_MAPPING = {
    'Helpdesk::TicketField' => 'fetch_custom_field_choices'
  }.freeze

  CLASS_NAME_MAPPING = {
    'Helpdesk::TicketField' => 'ticket_fields'
  }.freeze

  DEFAULT_FIELDS = ['requester', 'subject', 'priority', 'group', 'agent', 'product', 'description', 'company'].freeze
  def wrap_cname(params)
    params
  end

  def setup
    super
    supported_languages = ['de', 'fr', 'ja-JP', 'ko']
    Account.current.add_feature(:custom_translations)
    Account.any_instance.stubs(:supported_languages).returns(supported_languages)
    Account.any_instance.stubs(:language).returns('en')
    Account.current.stubs(:ticket_source_revamp_enabled?).returns(true)
    Sidekiq::Worker.clear_all
    setup_fields
    @language = supported_languages.sample
  end

  def teardown
    Account.current.revoke_feature(:custom_translations)
    Account.any_instance.unstub(:supported_languages)
    Account.any_instance.unstub(:language)
    Account.current.unstub(:ticket_source_revamp_enabled?)
    CustomTranslation.delete_all
    super
  end

  def setup_fields
    @fields = []
    @fields << create_custom_field('test_custom_text', 'text') || get_ticket_field('test_custom_text')
    @fields << create_custom_field_dropdown('test_custom_dropdown', ['Get Smart', 'Pursuit of Happiness', 'Armaggedon']) || get_ticket_field('test_custom_dropdown')
    @fields << create_dependent_custom_field(['test_custom_country', 'test_custom_state', 'test_custom_city']) || get_ticket_field('test_custom_country')
  end

  def get_ticket_field(name)
    Account.current.ticket_fields.where(name: name).limit(1).first
  end

  def yaml_payload(fields, only_customer_label = false)
    payload = { @language => { 'custom_translations' => { 'ticket_fields' => {}, 'company_fields' => {}, 'contact_fields' => {} } } }
    fields.each do |field|
      field_translations = {
        'label' => Faker::Lorem.word,
        'customer_label' => Faker::Lorem.word
      }
      if TICKET_FIELDS_WITH_CHOICES.include?(field.field_type)
        choices_keys = field.safe_send(CHOICE_MAPPING[field.class.to_s])
        choices = {}
        choices_keys.map { |choice| choices[choice[0]] = Faker::Lorem.word }
        field_translations['choices'] = choices
      end
      field_translations.delete('customer_label') if field.name == 'source'
      field_translations.slice!('customer_label') if only_customer_label
      translation_field_type = CLASS_NAME_MAPPING[field.class.to_s]
      payload[@language]['custom_translations'][translation_field_type][field.name] = field_translations
    end
    payload
  end

  def write_yaml(payload)
    file_content = {}
    file_content[@language] = payload[@language]
    File.open('test/api/fixtures/files/translation_file.yaml', 'w') { |f| f.write YAML.dump(file_content) }
  end

  def get_field_translation(ticket_field)
    ticket_field.safe_send("#{Language.find_by_code(@language).to_key}_translation").translations
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

  def test_ticket_field_upload_with_basic_field
    fields = [@fields.detect { |c| c.field_type == 'custom_text' }]
    payload = yaml_payload(fields)
    write_yaml(payload)
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    file = fixture_file_upload('files/translation_file.yaml', 'test/yaml', :binary)
    stub_params_for_translations(payload)
    Sidekiq::Testing.inline! do
      post :upload, construct_params({ id: @language }, translation_file: file)
    end
    unstub_params_for_translations
    assert_response 202
    translation = get_field_translation(fields[0])
    assert translation == payload[@language]['custom_translations']['ticket_fields'][fields[0].name], 'Translations do not match!'
  end

  DEFAULT_FIELDS.map do |field|
    define_method "test_ticket_field_upload_with_#{field}" do
      db_field = get_ticket_field(field)
      payload = yaml_payload([db_field], true)
      write_yaml(payload)
      @request.env['CONTENT_TYPE'] = 'multipart/form-data'
      file = fixture_file_upload('files/translation_file.yaml', 'test/yaml', :binary)
      stub_params_for_translations(payload)
      Sidekiq::Testing.inline! do
        post :upload, construct_params({ id: @language }, translation_file: file)
      end
      unstub_params_for_translations
      assert_response 202
      translation = get_field_translation(db_field)
      refute_empty translation
      assert_nil translation['label']
      assert_nil translation['choices']
      assert_equal translation['customer_label'], payload[@language]['custom_translations']['ticket_fields'][db_field.name]['customer_label']
    end

    define_method "test_ticket_field_upload_with_#{field}_even_label_and_choices" do
      db_field = get_ticket_field(field)
      payload = yaml_payload([db_field], false)
      write_yaml(payload)
      @request.env['CONTENT_TYPE'] = 'multipart/form-data'
      file = fixture_file_upload('files/translation_file.yaml', 'test/yaml', :binary)
      stub_params_for_translations(payload)
      Sidekiq::Testing.inline! do
        post :upload, construct_params({ id: @language }, translation_file: file)
      end
      unstub_params_for_translations
      assert_response 202
      translation = get_field_translation(db_field)
      refute_empty translation
      assert_nil translation['label']
      assert_nil translation['choices']
      assert_equal translation['customer_label'], payload[@language]['custom_translations']['ticket_fields'][db_field.name]['customer_label']
    end
  end

  def test_ticket_field_upload_with_dropdown
    fields = [@fields.detect { |c| c.field_type == 'custom_dropdown' }]
    payload = yaml_payload(fields)
    write_yaml(payload)
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    file = fixture_file_upload('files/translation_file.yaml', 'test/yaml', :binary)
    stub_params_for_translations(payload)
    Sidekiq::Testing.inline! do
      post :upload, construct_params({ id: @language }, translation_file: file)
    end
    unstub_params_for_translations
    assert_response 202
    translation = get_field_translation(fields[0])
    assert translation == payload[@language]['custom_translations']['ticket_fields'][fields[0].name], 'Translations do not match!'
  end

  def test_ticket_field_upload_with_invalid_choices
    fields = [@fields.detect { |c| c.field_type == 'custom_dropdown' }]
    payload = yaml_payload(fields)
    field_translations = payload[@language]['custom_translations']['ticket_fields']['test_custom_dropdown_1']
    fake_choice = 'choice_123456788'
    field_translations['choices'][fake_choice] = Faker::Lorem.word
    write_yaml(payload)
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    file = fixture_file_upload('files/translation_file.yaml', 'test/yaml', :binary)
    stub_params_for_translations(payload)
    Sidekiq::Testing.inline! do
      post :upload, construct_params({ id: @language }, translation_file: file)
    end
    unstub_params_for_translations
    assert_response 202
    field_translations['choices'].delete(fake_choice)
    translations = get_field_translation(fields[0])
    assert translations == payload[@language]['custom_translations']['ticket_fields'][fields[0].name], 'Translations do not match!'
  end

  def test_ticket_field_upload_with_nested_field
    fields = []
    nested_field_levels = []
    fields << nested_field_parent = @fields.detect { |c| c.field_type == 'nested_field' }
    nested_field_parent.child_levels.map { |child| fields << child }
    payload = yaml_payload(fields)
    write_yaml(payload)
    ticket_field_translations = payload[@language]['custom_translations']['ticket_fields']
    fields.map { |field| nested_field_levels << [field.level, ticket_field_translations[field.name]] }
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    file = fixture_file_upload('files/translation_file.yaml', 'test/yaml', :binary)
    stub_params_for_translations(payload)
    Sidekiq::Testing.inline! do
      post :upload, construct_params({ id: @language }, translation_file: file)
    end
    unstub_params_for_translations
    ticket_field_translations = payload[@language]['custom_translations']['ticket_fields']
    ticket_field_translations[nested_field_parent.name] = merge_nested_translations(nested_field_levels)
    nested_field_parent.child_levels.map { |child| ticket_field_translations.delete(child.name) }
    assert_response 202
    translations = get_field_translation(nested_field_parent)
    assert translations == payload[@language]['custom_translations']['ticket_fields'][nested_field_parent.name], 'Translations do not match!'
  end

  def test_ticket_field_upload_with_multiple_fields_in_yml
    fields = @fields.dup
    nested_field_levels = []
    nested_field_parent = @fields.detect { |c| c.field_type == 'nested_field' }
    nested_field_parent.child_levels.map { |child| fields << child }
    payload = yaml_payload(fields)
    write_yaml(payload)
    ticket_field_translations = payload[@language]['custom_translations']['ticket_fields']
    nested_field_levels << [nil, ticket_field_translations[nested_field_parent.name]]
    nested_field_parent.child_levels.map { |child| nested_field_levels << [child.level, ticket_field_translations[child.name]] }
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    file = fixture_file_upload('files/translation_file.yaml', 'test/yaml', :binary)
    stub_params_for_translations(payload)
    Sidekiq::Testing.inline! do
      post :upload, construct_params({ id: @language }, translation_file: file)
    end
    unstub_params_for_translations
    ticket_field_translations[nested_field_parent.name] = merge_nested_translations(nested_field_levels)
    nested_field_parent.child_levels.map { |child| ticket_field_translations.delete(child.name) }
    assert_response 202
    fields.each do |field|
      next unless field.level.nil?
      translations = get_field_translation(field)
      assert translations == ticket_field_translations[field.name], 'Translations do not match!'
    end
  end

  def test_ticket_field_upload_with_empty_field
    fields = [@fields.detect { |c| c.field_type == 'custom_dropdown' }]
    payload = yaml_payload(fields)
    write_yaml(payload)
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    file = fixture_file_upload('files/translation_file.yaml', 'test/yaml', :binary)
    stub_params_for_translations(payload)
    Sidekiq::Testing.inline! do
      post :upload, construct_params({ id: @language }, translation_file: file)
    end
    unstub_params_for_translations
    assert 202
    ticket_field_translations = payload[@language]['custom_translations']['ticket_fields'][fields[0].name]
    ticket_field_translations['label'] = nil
    choice_keys = ticket_field_translations['choices'].keys
    ticket_field_translations['choices'][choice_keys[0]] = nil
    stub_params_for_translations(payload)
    Sidekiq::Testing.inline! do
      post :upload, construct_params({ id: @language }, translation_file: file)
    end
    unstub_params_for_translations
    assert 202
    ticket_field_translations.delete('label')
    ticket_field_translations['choices'].delete(choice_keys[0])
    translation = get_field_translation(fields[0])
    assert translation == payload[@language]['custom_translations']['ticket_fields'][fields[0].name], 'Translations do not match!'
  end

  def test_ticket_field_upload_with_abscent_translations
    fields = [@fields.detect { |c| c.field_type == 'custom_dropdown' }]
    payload = yaml_payload(fields)
    write_yaml(payload)
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    file = fixture_file_upload('files/translation_file.yaml', 'test/yaml', :binary)
    stub_params_for_translations(payload)
    Sidekiq::Testing.inline! do
      post :upload, construct_params({ id: @language }, translation_file: file)
    end
    unstub_params_for_translations
    assert 202
    ticket_field_translations = payload[@language]['custom_translations']['ticket_fields'][fields[0].name]
    ticket_field_translations['label'] = Faker::Lorem.word
    payload_copy = payload.deep_dup
    ticket_field_translations.delete('customer_label')
    choice_keys = ticket_field_translations['choices'].keys
    ticket_field_translations['choices'].delete(choice_keys[0])
    stub_params_for_translations(payload)
    Sidekiq::Testing.inline! do
      post :upload, construct_params({ id: @language }, translation_file: file)
    end
    unstub_params_for_translations
    assert 202
    translation = get_field_translation(fields[0])
    assert translation == payload_copy[@language]['custom_translations']['ticket_fields'][fields[0].name], 'Translations do not match!'
  end

  def test_ticket_field_upload_with_invalid_keys
    fields = [@fields.detect { |c| c.field_type == 'custom_dropdown' }]
    payload = yaml_payload(fields)
    ticket_field_translations = payload[@language]['custom_translations']['ticket_fields'][fields[0].name]
    ticket_field_translations['INVALID_FIELD'] = Faker::Lorem.word
    write_yaml(payload)
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    file = fixture_file_upload('files/translation_file.yaml', 'test/yaml', :binary)
    stub_params_for_translations(payload)
    Sidekiq::Testing.inline! do
      post :upload, construct_params({ id: @language }, translation_file: file)
    end
    unstub_params_for_translations
    assert_response 202
    ticket_field_translations.delete('INVALID_FIELD')
    translation = get_field_translation(fields[0])
    assert translation == payload[@language]['custom_translations']['ticket_fields'][fields[0].name], 'Translations do not match!'
  end

  def test_ticket_field_upload_with_jumbled_levels
    fields = []
    nested_field_levels = []
    nested_field_parent = @fields.detect { |c| c.field_type == 'nested_field' }
    nested_field_parent.child_levels.map { |child| fields << child }
    fields << nested_field_parent
    payload = yaml_payload(fields)
    write_yaml(payload)
    ticket_field_translations = payload[@language]['custom_translations']['ticket_fields']
    fields.map { |field| nested_field_levels << [field.level, ticket_field_translations[field.name]] }
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    file = fixture_file_upload('files/translation_file.yaml', 'test/yaml', :binary)
    stub_params_for_translations(payload)
    Sidekiq::Testing.inline! do
      post :upload, construct_params({ id: @language }, translation_file: file)
    end
    unstub_params_for_translations
    ticket_field_translations = payload[@language]['custom_translations']['ticket_fields']
    ticket_field_translations[nested_field_parent.name] = merge_nested_translations(nested_field_levels)
    nested_field_parent.child_levels.map { |child| ticket_field_translations.delete(child.name) }
    assert_response 202
    translations = get_field_translation(nested_field_parent)
    assert translations == payload[@language]['custom_translations']['ticket_fields'][nested_field_parent.name], 'Translations do not match!'
  end

  def test_ticket_field_upload_with_no_nested_field_parent_translation
    fields = []
    nested_field_levels = []
    nested_field_parent = @fields.detect { |c| c.field_type == 'nested_field' }
    nested_field_parent.child_levels.map { |child| fields << child }
    payload = yaml_payload(fields)
    write_yaml(payload)
    ticket_field_translations = payload[@language]['custom_translations']['ticket_fields']
    fields.map { |field| nested_field_levels << [field.level, ticket_field_translations[field.name]] }
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    file = fixture_file_upload('files/translation_file.yaml', 'test/yaml', :binary)
    stub_params_for_translations(payload)
    Sidekiq::Testing.inline! do
      post :upload, construct_params({ id: @language }, translation_file: file)
    end
    unstub_params_for_translations
    ticket_field_translations = payload[@language]['custom_translations']['ticket_fields']
    ticket_field_translations[nested_field_parent.name] = merge_nested_translations(nested_field_levels)
    nested_field_parent.child_levels.map { |child| ticket_field_translations.delete(child.name) }
    assert_response 202
    translations = get_field_translation(nested_field_parent)
    assert translations == payload[@language]['custom_translations']['ticket_fields'][nested_field_parent.name], 'Translations do not match!'
  end

  def test_ticket_field_upload_with_source
    field = get_ticket_field('source')
    payload = yaml_payload([field])
    write_yaml(payload)
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    file = fixture_file_upload('files/translation_file.yaml', 'test/yaml', :binary)
    stub_params_for_translations(payload)
    Sidekiq::Testing.inline! do
      post :upload, construct_params({ id: @language }, translation_file: file)
    end
    unstub_params_for_translations
    assert_response 202
    translation = get_field_translation(field)
    assert translation == payload[@language]['custom_translations']['ticket_fields'][field.name], 'Translations do not match!'
  end

  # test cases for validation
  def test_upload_with_invalid_file_format
    file = fixture_file_upload('files/attachment.txt', 'plain/text', :binary)
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    Account.any_instance.stubs(:custom_translations_enabled?).returns(true)
    Sidekiq::Testing.inline! do
      post :upload, construct_params({ id: @language }, translation_file: file)
    end
    Account.any_instance.unstub(:custom_translations_enabled?)
    assert_response 400
    match_json([bad_request_error_pattern('translation_file', :invalid_upload_file_type, current_extension: 'txt')])
  end

  def test_upload_with_mismatching_language_code
    fields = [create_custom_field('test_custom_text', 'text')]
    payload = yaml_payload(fields)
    write_yaml(payload)
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    file = fixture_file_upload('files/translation_file.yaml', 'test/yaml', :binary)
    Account.any_instance.stubs(:custom_translations_enabled?).returns(true)
    Sidekiq::Testing.inline! do
      post :upload, construct_params({ id: 'it' }, translation_file: file)
    end
    Account.any_instance.unstub(:custom_translations_enabled?)
    assert_response 400
    match_json([bad_request_error_pattern('translation_file', :mismatch_language)])
  end

  def test_upload_for_primary_language
    language_prev = @language
    @language = Account.current.language
    fields = [create_custom_field('test_custom_text', 'text')]
    payload = yaml_payload(fields)
    write_yaml(payload)
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    file = fixture_file_upload('files/translation_file.yaml', 'test/yaml', :binary)
    Account.any_instance.stubs(:custom_translations_enabled?).returns(true)
    Sidekiq::Testing.inline! do
      post :upload, construct_params({ id: @language }, translation_file: file)
    end
    Account.any_instance.unstub(:custom_translations_enabled?)
    @language = language_prev
    assert_response 400
    match_json([bad_request_error_pattern('translation_file', :primary_lang_translations_not_allowed)])
  end

  def test_upload_with_unpermitted_language_code
    permitted_language_list = Account.current.supported_languages
    all_languages = []
    Language.all.map { |lang| all_languages << lang.code }
    unpermitted_languages = all_languages - permitted_language_list - [Account.current.language]
    language_prev = @language
    @language = unpermitted_languages.sample
    fields = [create_custom_field('test_custom_text', 'text')]
    payload = yaml_payload(fields)
    write_yaml(payload)
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    file = fixture_file_upload('files/translation_file.yaml', 'test/yaml', :binary)
    Account.any_instance.stubs(:custom_translations_enabled?).returns(true)
    Sidekiq::Testing.inline! do
      post :upload, construct_params({ id: @language }, translation_file: file)
    end
    Account.any_instance.unstub(:custom_translations_enabled?)
    assert_response 400
    match_json([bad_request_error_pattern('translation_file', :unsupported_language, language_code: @language, list: permitted_language_list.sort.join(', '))])
    @language = language_prev
  end

  def test_upload_with_file_as_string
    file = "hfjksdhfkjds"
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    Account.any_instance.stubs(:custom_translations_enabled?).returns(true)
    Sidekiq::Testing.inline! do
      post :upload, construct_params({ id: @language }, translation_file: file)
    end
    Account.any_instance.unstub(:custom_translations_enabled?)
    assert_response 400
    match_json([bad_request_error_pattern('translation_file', :no_file_uploaded)])
  end 

  def stub_params_for_translations(payload)
    Account.any_instance.stubs(:custom_translations_enabled?).returns(true)
    AwsWrapper::S3.stubs(:read).returns(YAML.dump(payload))
  end

  def unstub_params_for_translations
    AwsWrapper::S3.unstub(:read)
    Account.any_instance.unstub(:custom_translations_enabled?)
  end
end
