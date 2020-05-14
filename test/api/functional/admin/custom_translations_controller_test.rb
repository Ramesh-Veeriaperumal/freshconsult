require_relative '../../test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
class Admin::CustomTranslationsControllerTest < ActionController::TestCase
  include SurveysTestHelper
  include ActionView::Helpers::NumberHelper

  MODULES = ['surveys'].freeze

  def stub_for_custom_translations
    supported_languages = ['de', 'fr', 'ko']
    all_languages = ['en', 'de', 'fr', 'ko']
    @language = supported_languages.sample
    Account.current.add_feature(:custom_translations)
    Account.any_instance.stubs(:supported_languages).returns(supported_languages)
    Account.any_instance.stubs(:language).returns('en')
    Account.any_instance.stubs(:all_languages).returns(all_languages)
  end

  def unstub_for_custom_translations
    Account.current.revoke_feature(:custom_translations)
    Account.any_instance.unstub(:supported_languages)
    Account.any_instance.unstub(:language)
    Account.any_instance.unstub(:all_languages)
  end

  def wrap_cname(params)
    params
  end

  def create_survey_questions(survey)
    3.times do |x|
      sq = survey.survey_questions.create('type' => 'survey_radio', 'field_type' => 'custom_survey_radio', 'label' => ' How would you rate your overallsatisfaction for the resolution provided by the agent?', 'name' => "cf_how_would_you_rate_your_overallsatisfaction_for_the_resolution_provided_by_the_agent#{x}", 'custom_field_choices_attributes' => [{ 'value' => 'Extremelydissatisfied', 'face_value' => -103, 'position' => 1, '_destroy' => 0 }, { 'value' => 'Neithersatisfied nor dissatisfied', 'face_value' => 100, 'position' => 2, '_destroy' => 0 }, { 'value' => 'Extremely satisfied', 'face_value' => 103, 'position' => 3, '_destroy' => 0 }], 'action' => 'create', 'default' => false, 'position' => 1)
      sq.column_name = "cf_int0#{x + 2}"
      sq.save
    end
  end

  def generate_content(survey)
    payload = { @language => { 'custom_translations' => { 'surveys' => {} } } }
    default_question = { 'question' => Faker::Lorem.sentence(1) }
    additional_question = Hash[survey.survey_questions.where(default: false).map { |x| ["question_#{x.id}", Faker::Lorem.sentence(1)] }]
    default_question_choices = { 'choices' => Hash[survey.survey_questions.where(default: true).first.choices.map { |x| [x[:face_value], Faker::Lorem.sentence(1)] }] }
    additional_question_choices = !additional_question.empty? ? { 'choices' => Hash[survey.survey_questions.where(default: false).first.choices.map { |x| [x[:face_value], Faker::Lorem.sentence(1)] }] } : {}
    default_question_set = default_question.merge(default_question_choices)
    additional_question_set = additional_question.merge(additional_question_choices)
    survey_content = {
      "survey_#{survey.id}" => {
        'title_text' => Faker::Lorem.sentence(1),
        'comments_text' => Faker::Lorem.sentence(1),
        'thanks_text' => Faker::Lorem.sentence(1),
        'feedback_response_text' => Faker::Lorem.sentence(1)
      }.merge('default_question' => default_question_set).merge('additional_questions' => additional_question_set)
    }
    payload[@language]['custom_translations']['surveys'] = payload[@language]['custom_translations']['surveys'].merge(survey_content)
    payload
  end

  def write_yaml(payload)
    file_content = {}
    file_content[@language] = payload[@language]
    File.open('test/api/fixtures/files/translation_file.yaml', 'w') { |f| f.write file_content.to_yaml }
  end

  def test_upload_file_validation_invalid_extension
    stub_for_custom_translations
    create_survey(1, true)
    survey = Account.current.custom_surveys.last
    create_survey_questions(survey)
    payload = generate_content(survey)
    write_yaml(payload)
    # file = Rack::Test::UploadedFile.new(Rails.root.join('test/api/fixtures/files/translation_file.yaml'), 'test/yaml')
    File.open('test/api/fixtures/files/translation_file.test', 'w') { |f| f.write payload.to_yaml }
    file = fixture_file_upload('files/translation_file.test', 'test/test', :binary)
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    YAML.stubs(:safe_load).returns(payload)
    put :upload, construct_params({ object_type: 'surveys', object_id: survey.id }, translation_file: file, language_code: @language)
    assert_response 400
    assert_equal JSON.parse(response.body)['errors'].first['message'], 'This file type is not supported. Please upload a yml/yaml file.'
    YAML.unstub(:safe_load)
    unstub_for_custom_translations
  end

  def test_upload_unsupported_language
    stub_for_custom_translations
    create_survey(1, true)
    survey = Account.current.custom_surveys.last
    create_survey_questions(survey)
    payload = generate_content(survey)
    write_yaml(payload)
    # file = Rack::Test::UploadedFile.new(Rails.root.join('test/api/fixtures/files/translation_file.yaml'), 'test/yaml')
    file = fixture_file_upload('files/translation_file.yaml', 'test/yaml', :binary)
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    YAML.stubs(:safe_load).returns(payload)
    lang = 'ab'
    put :upload, construct_params({ object_type: 'surveys', object_id: survey.id }, translation_file: file, language_code: 'ab')
    assert_response 400
    assert_equal JSON.parse(response.body)['errors'].first['message'], "File mismatch. This file contains another supported language."
    YAML.unstub(:safe_load)
    unstub_for_custom_translations
  end

  def test_upload_no_file
    stub_for_custom_translations
    create_survey(1, true)
    survey = Account.current.custom_surveys.last
    create_survey_questions(survey)
    payload = generate_content(survey)
    write_yaml(payload)
    # file = Rack::Test::UploadedFile.new(Rails.root.join('test/api/fixtures/files/translation_file.yaml'), 'test/yaml')
    file = 'sample file'
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    YAML.stubs(:safe_load).returns(payload)
    put :upload, construct_params({ object_type: 'surveys', object_id: survey.id }, translation_file: file, language_code: @language)
    assert_response 400
    assert_equal JSON.parse(response.body)['errors'].first['message'], 'No file uploaded!'
    YAML.unstub(:safe_load)
    unstub_for_custom_translations
  end

  def test_upload_invalid_yaml_code
    stub_for_custom_translations
    create_survey(1, true)
    survey = Account.current.custom_surveys.last
    create_survey_questions(survey)
    payload = generate_content(survey)
    write_yaml(payload)
    # file = Rack::Test::UploadedFile.new(Rails.root.join('test/api/fixtures/files/translation_file.yaml'), 'test/yaml')
    file = fixture_file_upload('files/translation_file.yaml', 'test/yaml', :binary)
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    payload = { ca: { custom_translations: { surveys: {} } } }
    YAML.stubs(:safe_load).returns(payload)
    put :upload, construct_params({ object_type: 'surveys', object_id: survey.id }, translation_file: file, language_code: @language)
    assert_response 400
    assert_equal JSON.parse(response.body)['errors'].first['message'], 'File mismatch. This file contains another supported language.'
    YAML.unstub(:safe_load)
    unstub_for_custom_translations
  end

  def test_upload_primary_language
    stub_for_custom_translations
    create_survey(1, true)
    survey = Account.current.custom_surveys.last
    create_survey_questions(survey)
    payload = generate_content(survey)
    write_yaml(payload)
    # file = Rack::Test::UploadedFile.new(Rails.root.join('test/api/fixtures/files/translation_file.yaml'), 'test/yaml')
    file = fixture_file_upload('files/translation_file.yaml', 'test/yaml', :binary)
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    YAML.stubs(:safe_load).returns(payload)
    lang = Account.current.language
    put :upload, construct_params({ object_type: 'surveys', object_id: survey.id }, translation_file: file, language_code: lang)
    assert_response 400
    assert_equal JSON.parse(response.body)['errors'].first['message'], 'File mismatch. This file contains another supported language.'
    YAML.unstub(:safe_load)
    unstub_for_custom_translations
  end

  def test_upload_single_survey
    stub_for_custom_translations
    create_survey(1, true)
    survey = Account.current.custom_surveys.last
    create_survey_questions(survey)
    payload = generate_content(survey)
    write_yaml(payload)
    # file = Rack::Test::UploadedFile.new(Rails.root.join('test/api/fixtures/files/translation_file.yaml'), 'test/yaml')
    file = fixture_file_upload('files/translation_file.yaml', 'test/yaml', :binary)
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    YAML.stubs(:safe_load).returns(payload)
    put :upload, construct_params({ object_type: 'surveys', object_id: survey.id }, translation_file: file, language_code: @language)
    assert_response 200
    custom_translations_record = survey.safe_send("#{@language}_translation")
    assert custom_translations_record.present?
    assert custom_translations_record.status == 1
    YAML.unstub(:safe_load)
    unstub_for_custom_translations
  end

  def test_upload_single_survey_update
    stub_for_custom_translations
    create_survey(1, true)
    survey = Account.current.custom_surveys.last
    create_survey_questions(survey)
    payload = generate_content(survey)
    write_yaml(payload)
    # file = Rack::Test::UploadedFile.new(Rails.root.join('test/api/fixtures/files/translation_file.yaml'), 'test/yaml')
    file = fixture_file_upload('files/translation_file.yaml', 'test/yaml', :binary)
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    YAML.stubs(:safe_load).returns(payload)
    put :upload, construct_params({ object_type: 'surveys', object_id: survey.id }, translation_file: file, language_code: @language)
    assert_response 200
    custom_translations_record = survey.safe_send("#{@language}_translation")
    assert custom_translations_record.present?

    payload = generate_content(survey)
    write_yaml(payload)
    ile = fixture_file_upload('files/translation_file.yaml', 'test/yaml', :binary)
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    YAML.stubs(:safe_load).returns(payload)
    put :upload, construct_params({ object_type: 'surveys', object_id: survey.id }, translation_file: file, language_code: @language)
    assert_response 200
    custom_translations_record = survey.safe_send("#{@language}_translation")
    assert custom_translations_record.present?
    assert custom_translations_record.status == 1
    YAML.unstub(:safe_load)
    unstub_for_custom_translations
  end

  def test_upload_single_survey_incomplete_data_missing
    stub_for_custom_translations
    create_survey(1, true)
    survey = Account.current.custom_surveys.last
    create_survey_questions(survey)
    payload = generate_content(survey)
    payload[@language]['custom_translations']['surveys']["survey_#{survey.id}"].delete('additional_questions')
    write_yaml(payload)
    # file = Rack::Test::UploadedFile.new(Rails.root.join('test/api/fixtures/files/translation_file.yaml'), 'test/yaml')
    file = fixture_file_upload('files/translation_file.yaml', 'test/yaml', :binary)
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    YAML.stubs(:safe_load).returns(payload)
    put :upload, construct_params({ object_type: 'surveys', object_id: survey.id }, translation_file: file, language_code: @language)
    assert_response 200
    custom_translations_record = survey.safe_send("#{@language}_translation")
    assert custom_translations_record.present?
    assert custom_translations_record.status == 3
    YAML.unstub(:safe_load)
    unstub_for_custom_translations
  end

  def test_upload_single_survey_merge
    stub_for_custom_translations
    create_survey(1, true)
    survey = Account.current.custom_surveys.last
    create_survey_questions(survey)
    payload = generate_content(survey)
    payload[@language]['custom_translations']['surveys']["survey_#{survey.id}"].delete('additional_questions')
    write_yaml(payload)
    # file = Rack::Test::UploadedFile.new(Rails.root.join('test/api/fixtures/files/translation_file.yaml'), 'test/yaml')
    file = fixture_file_upload('files/translation_file.yaml', 'test/yaml', :binary)
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    YAML.stubs(:safe_load).returns(payload)
    put :upload, construct_params({ object_type: 'surveys', object_id: survey.id }, translation_file: file, language_code: @language)
    assert_response 200
    custom_translations_record = survey.safe_send("#{@language}_translation")
    assert custom_translations_record.present?

    payload = generate_content(survey)
    payload[@language]['custom_translations']['surveys']["survey_#{survey.id}"].delete('default_question')
    write_yaml(payload)
    ile = fixture_file_upload('files/translation_file.yaml', 'test/yaml', :binary)
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    YAML.stubs(:safe_load).returns(payload)
    put :upload, construct_params({ object_type: 'surveys', object_id: survey.id }, translation_file: file, language_code: @language)
    assert_response 200
    custom_translations_record = survey.safe_send("#{@language}_translation")
    assert custom_translations_record.present?
    YAML.unstub(:safe_load)
    unstub_for_custom_translations
  end

  def assert_survey(survey, response_hash)
    assert_equal response_hash['title_text'], survey.title_text
    assert_equal response_hash['comments_text'], survey.comments_text
    assert_equal response_hash['thanks_text'], survey.thanks_text
    assert_equal response_hash['feedback_response_text'], survey.feedback_response_text
    # Default question and choices
    default_question = survey.default_question
    assert_equal response_hash['default_question']['question'], default_question.label
    default_question.choices.each do |choice|
      assert_equal response_hash['default_question']['choices'][choice[:face_value]], choice[:value]
    end
    # Additional questions and choices
    additional_questions = survey.survey_questions.reject(&:default)
    additional_questions.each do |question|
      assert_equal response_hash['additional_questions']["question_#{question.id}"], question.label
    end
    (additional_questions.first.try(:choices) || []).each do |choice|
      assert_equal response_hash['additional_questions']['choices'][choice[:face_value]], choice[:value]
    end
  end

  def assert_response_secondary_download(survey_hash, response_hash)
    assert_equal response_hash['title_text'], survey_hash['title_text'] || ''
    assert_equal response_hash['comments_text'], survey_hash['comments_text'] || ''
    assert_equal response_hash['thanks_text'], survey_hash['thanks_text'] || ''
    assert_equal response_hash['feedback_response_text'], survey_hash['feedback_response_text'] || ''
    assert_equal response_hash['default_question']['question'], survey_hash['default_question']['question'] || ''
    # Default question and choices
    response_hash['default_question']['choices'].each_key do |key|
      assert_equal response_hash['default_question']['choices'][key], survey_hash['default_question']['choices'][key] || ''
    end
    # Additional questions and choices
    ((response_hash['additional_questions'] || {}).keys - ['choices']).each do |question|
      assert_equal response_hash['additional_questions'][question], survey_hash['additional_questions'][question] || ''
    end
    ((response_hash['additional_question'] || {})['choices'] || {}).each_key do |key|
      assert_equal response_hash['additional_question']['choices'][key], survey_hash['additional_question']['choices'][key] || ''
    end
  end

  def test_primary_download_for_surveys_with_id
    stub_for_custom_translations
    create_survey(1, true)
    survey = Account.current.custom_surveys.last
    create_survey_questions(survey)
    language = Account.current.language
    get :download, controller_params('object_type' => 'surveys', 'object_id' => survey.id)
    response_hash = YAML.safe_load(response.body)[language]['custom_translations']['surveys']["survey_#{survey.id}"]
    assert_survey(survey, response_hash)
    survey.destroy
    unstub_for_custom_translations
  end

  def test_primary_download_for_all_surveys
    stub_for_custom_translations
    surveys = []
    3.times do
      create_survey(1, true)
      surveys << s = Account.current.custom_surveys.last
      create_survey_questions(s)
    end
    language = Account.current.language
    get :download, controller_params('object_type' => 'surveys')
    response_hash = YAML.safe_load(response.body)[language]['custom_translations']['surveys']
    assert_equal response_hash.keys.count, Account.current.custom_surveys.count
    Account.current.custom_surveys.each do |survey|
      assert_survey(survey, response_hash["survey_#{survey.id}"])
      survey.destroy unless survey.default?
    end
    unstub_for_custom_translations
  end

  def test_primary_download_with_invalid_id
    stub_for_custom_translations
    create_survey(1, true)
    survey = Account.current.custom_surveys.last
    survey_id = Account.current.custom_surveys.pluck(:id).max
    object_id = survey_id.nil? ? 2 : survey_id + 10
    get :download, controller_params('object_type' => 'surveys', 'object_id' => object_id)
    assert_response 400
    match_json([bad_request_error_pattern('object_id', :invalid_object_id, object: 'surveys')])
    survey.destroy
    unstub_for_custom_translations
  end

  def test_primary_download_with_invalid_type
    stub_for_custom_translations
    create_survey(1, true)
    survey = Account.current.custom_surveys.last
    object_type = Faker::Lorem.words(1)
    get :download, controller_params('object_type' => object_type, 'object_id' => survey.id)
    assert_response 400
    match_json([bad_request_error_pattern('object_type', :not_included, list: Admin::CustomTranslationsConstants::MODULE_MODEL_MAPPINGS.keys.join(','))])
    survey.destroy
    unstub_for_custom_translations
  end

  def test_primary_download_with_id_given_type_nil
    stub_for_custom_translations
    create_survey(1, true)
    survey = Account.current.custom_surveys.last
    get :download, controller_params('object_id' => 123)
    match_json([bad_request_error_pattern('object_type', :missing_param, code: :missing_field)])
    survey.destroy
    unstub_for_custom_translations
  end

  def test_primary_download_without_additional_questions
    stub_for_custom_translations
    create_survey(1, true)
    language = Account.current.language
    survey = Account.current.custom_surveys.last
    get :download, controller_params('object_type' => 'surveys', 'object_id' => survey.id)
    response_hash = YAML.safe_load(response.body)[language]['custom_translations']['surveys']["survey_#{survey.id}"]
    assert !response_hash.key?('additional_questions')
    survey.destroy
    unstub_for_custom_translations
  end

  def test_secondary_download_for_surveys_with_id
    stub_for_custom_translations
    create_survey(1, true)
    survey = Account.current.custom_surveys.last
    create_survey_questions(survey)
    language_code = Account.current.supported_languages.sample
    translation = generate_content(survey)
    survey.safe_send("build_#{@language}_translation", translations: translation[@language]['custom_translations']['surveys']["survey_#{survey.id}"]).save!
    get :download, controller_params('object_type' => 'surveys', 'object_id' => survey.id, 'language_code' => @language)
    response_hash = YAML.safe_load(response.body)[@language]['custom_translations']['surveys']["survey_#{survey.id}"]
    survey_translation = survey.safe_send("#{@language}_translation").try(:translations) || {}
    assert_response_secondary_download(survey_translation, response_hash)
    unstub_for_custom_translations
  end

  def test_secondary_download_with_invalid_language_code
    stub_for_custom_translations
    create_survey(1, true)
    survey = Account.current.custom_surveys.last
    language_code = 'it'
    translation = generate_content(survey)
    get :download, controller_params('object_type' => 'surveys', 'object_id' => survey.id, 'language_code' => language_code)
    match_json([bad_request_error_pattern('language_code', :not_included, list: Account.current.all_languages.join(','))])
    unstub_for_custom_translations
  end

  def test_secondary_download_with_no_translations_given
    stub_for_custom_translations
    create_survey(1, true)
    survey = Account.current.custom_surveys.last
    language_code = Account.current.supported_languages.sample
    translation = generate_content(survey)
    get :download, controller_params('object_type' => 'surveys', 'object_id' => survey.id, 'language_code' => @language)
    response_hash = YAML.safe_load(response.body)[@language]['custom_translations']['surveys']["survey_#{survey.id}"]
    survey_translation = survey.safe_send("#{@language.underscore}_translation").try(:translations) || {}
    assert_equal response_hash['title_text'], ''
    assert_equal response_hash['comments_text'], ''
    assert_equal response_hash['thanks_text'], ''
    assert_equal response_hash['feedback_response_text'], ''
    survey.destroy
    unstub_for_custom_translations
  end

  def test_secodary_download_for_all_surveys
    stub_for_custom_translations
    surveys = []
    3.times do
      create_survey(1, true)
      surveys << s = Account.current.custom_surveys.last
      create_survey_questions(s)
      s.safe_send("build_#{@language}_translation", translations: generate_content(s)[@language]['custom_translations']['surveys']["survey_#{s.id}"]).save!
    end
    get :download, controller_params('object_type' => 'surveys', 'language_code' => @language)
    response_hash = YAML.safe_load(response.body)[@language]['custom_translations']['surveys']
    assert_equal response_hash.keys.count, Account.current.custom_surveys.count
    surveys.each do |survey|
      survey_translation = survey.safe_send("#{@language.underscore}_translation").try(:translations) || {}
      assert_response_secondary_download(survey_translation, response_hash["survey_#{survey.id}"])
      survey.destroy
    end
    unstub_for_custom_translations
  end

  def test_secondary_download_without_additional_questions
    stub_for_custom_translations
    create_survey(1, true)
    survey = Account.current.custom_surveys.last
    get :download, controller_params('object_type' => 'surveys', 'language_code' => @language)
    response_hash = YAML.safe_load(response.body)[@language]['custom_translations']['surveys']["survey_#{survey.id}"]
    assert !response_hash.key?('additional_questions')
    survey.destroy
    unstub_for_custom_translations
  end

  def test_survey_file_upload_limit
    stub_for_custom_translations
    create_survey(1, true)
    survey = Account.current.custom_surveys.last
    File.open('test/api/fixtures/files/translation_file.yaml', 'wb') do |f|
      f.write(SecureRandom.random_bytes(110.kilobytes))
    end
    file = fixture_file_upload('files/translation_file.yaml', 'test/yaml', :binary)
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    put :upload, construct_params({ object_type: 'surveys', object_id: survey.id }, translation_file: file, language_code: @language)
    assert_response 400
    match_json([bad_request_error_pattern('translation_file', :file_size_limit_error, file_size: number_to_human_size(100.kilobytes))])
    unstub_for_custom_translations
  end
end
