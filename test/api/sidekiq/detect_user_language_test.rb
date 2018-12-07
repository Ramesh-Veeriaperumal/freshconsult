require_relative '../../test_transactions_fixtures_helper'
require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'minitest'
Sidekiq::Testing.fake!
['contact_segments_test_helper.rb'].each { |file| require Rails.root.join("test/lib/helpers/#{file}") }
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
class DetectUserLanguageTest < ActionView::TestCase
  include ContactSegmentsTestHelper
  include AccountTestHelper
  include Redis::RedisKeys
  include Redis::OthersRedis

  def teardown
    super
    Account.unstub(:current)
    Google::APIClient.any_instance.unstub(:discovered_api)
    User.any_instance.unstub(:detect_language?)
    Google::APIClient.any_instance.unstub(:execute)
  end

  def setup
    @account = create_test_account
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @user = create_contact
    detections = Struct.new(:list)
    detections_mock = detections.new('/list')
    translate = Struct.new(:detections)
    translate_mock = translate.new(detections_mock)
    Google::APIClient.any_instance.stubs(:discovered_api).returns(translate_mock)
  end

  def test_language_detect
    response = Struct.new(:body)
    mock_response = response.new(sample_google_lang_response.to_json)
    Google::APIClient.any_instance.stubs(:execute).returns(mock_response)
    User.any_instance.stubs(:detect_language?).returns(true)
    Users::DetectLanguage.new.perform(user_id: @user.id, text: 'test string')
    @user.reload
    assert_equal 'ar', @user.language, 'language detection proper response from Google'
  end

  def test_language_detect_from_cache
    text = Faker::Lorem.sentence(7)
    key  = "DETECT_USER_LANGUAGE:#{text}"
    set_others_redis_key(key, 'ro', 600)
    response = Struct.new(:body)
    mock_response = response.new(sample_google_lang_response('de').to_json)
    Google::APIClient.any_instance.stubs(:execute).returns(mock_response)
    User.any_instance.stubs(:detect_language?).returns(true)
    Users::DetectLanguage.new.perform(user_id: @user.id, text: text)
    @user.reload
    assert_equal 'ro', @user.language
    assert_not_equal 'de', @user.language, 'language detection not from cache'
    remove_others_redis_key(key)
  end

  def test_language_detect_unkown_language
    response = Struct.new(:body)
    mock_response = response.new(sample_google_lang_response('yy').to_json)
    Google::APIClient.any_instance.stubs(:execute).returns(mock_response)
    User.any_instance.stubs(:detect_language?).returns(true)
    Users::DetectLanguage.new.perform(user_id: @user.id, text: 'test string - sample 1')
    @user.reload
    assert_equal @user.account.language, @user.language, 'language detection unkown language from Google'
  end

  def test_language_detect_failure
    response = Struct.new(:body)
    mock_response = response.new('{}'.to_json)
    Google::APIClient.any_instance.stubs(:execute).returns(mock_response)
    User.any_instance.stubs(:detect_language?).returns(true)
    Users::DetectLanguage.new.perform(user_id: @user.id, text: 'test string - sample 2')
    @user.reload
    assert_equal @user.account.language, @user.language, 'language detection improper response from google'
  end

  def test_language_detect_with_exception
    response = Struct.new(:body)
    mock_response = response.new('{}'.to_json)
    Google::APIClient.any_instance.stubs(:execute).raises(StandardError)
    User.any_instance.stubs(:detect_language?).returns(true)
    Users::DetectLanguage.new.perform(user_id: @user.id, text: 'test string - sample 3')
    @user.reload
    assert_equal @user.account.language, @user.language, 'language detection improper response from google'
  end

  def test_lang_detection_with_cld
    User.any_instance.stubs(:detect_language?).returns(true)
    @account.launch(:compact_lang_detection)
    Users::DetectLanguage.new.perform(user_id: @user.id, text: 'test string - sample 2')
    @user.reload
    assert_equal @user.language, "en"
    @account.rollback(:compact_lang_detection)
  end

  def sample_google_lang_response(lang = 'ar')
    { 'data' => {
      'detections' =>
          [
            [{
              'language' => 'en',
              'isReliable' => false,
              'confidence' => 0.134
            }],
            [{
              'language' => lang,
              'isReliable' => false,
              'confidence' => 0.9882
            }]
          ]
    } }
  end
end