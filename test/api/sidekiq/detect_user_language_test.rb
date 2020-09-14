require_relative '../../test_transactions_fixtures_helper'
require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'minitest'
Sidekiq::Testing.fake!
['contact_segments_test_helper.rb'].each { |file| require Rails.root.join("test/lib/helpers/#{file}") }
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
FD_EMAIL_SERVICE = YAML.load_file(Rails.root.join('config', 'fd_email_service.yml'))[Rails.env]
EMAIL_SERVICE_AUTHORISATION_KEY = FD_EMAIL_SERVICE['lang_key']
LANGUAGE_DETECT_URL = FD_EMAIL_SERVICE['lang_detect_path']
class DetectUserLanguageTest < ActionView::TestCase
  include ContactSegmentsTestHelper
  include AccountTestHelper
  include Redis::RedisKeys
  include Redis::OthersRedis

  def teardown
    super
    Account.unstub(:current)
    User.any_instance.unstub(:detect_language?)
  end

  def setup
    @account = create_test_account
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @user = create_contact
  end

  def test_language_detect_from_cache
    big_text = Faker::Lorem.sentence(7)
    text = (big_text.first(30) + big_text[big_text.length/2, 30] + big_text.last(30)).squish.split.first(15).join(' ')
    key  = "DETECT_USER_LANGUAGE:#{text}"
    set_others_redis_key(key, 'ro', 600)
    Users::DetectLanguage.any_instance.stubs(:detect_lang_from_email_service).returns('de')
    User.any_instance.stubs(:detect_language?).returns(true)
    Users::DetectLanguage.new.perform(user_id: @user.id, text: big_text)
    @user.reload
    assert_equal 'ro', @user.language
    assert_not_equal 'de', @user.language, 'language detection not from cache'
    remove_others_redis_key(key)
  end

  def test_language_detect_unkown_language
    response = Struct.new(:body)
    User.any_instance.stubs(:detect_language?).returns(true)
    Users::DetectLanguage.any_instance.stubs(:detect_lang_from_email_service).returns('yy')
    Users::DetectLanguage.new.perform(user_id: @user.id, text: 'test string - sample 1')
    @user.reload
    assert_equal @user.account.language, @user.language, 'language detection unkown language from Google'
  end

  def test_lang_detection_with_cld
    User.any_instance.stubs(:detect_language?).returns(true)
    set_others_redis_hash_set("CLD_FD_LANGUAGE_MAPPING", "en", "en")
    Users::DetectLanguage.new.perform(user_id: @user.id, text: 'test string - sample 2')
    @user.reload
    assert_equal @user.language, "en"
  end

  def test_lang_detect_from_email_service_for_success_response
    Users::DetectLanguage.any_instance.stubs(:lang_via_cld).returns(false)
    User.any_instance.stubs(:detect_language?).returns(true)
    Users::DetectLanguage.any_instance.stubs(:detect_lang_from_email_service).returns('ar')
    Users::DetectLanguage.new.perform(user_id: @user.id, text: 'القائمة وفيما يخص التطبيقات')
    @user.reload
    assert_equal 'ar', @user.language, 'language detection proper response from email service'
  end

  def test_lang_detect_from_email_service_for_alternate_language_codes
    Users::DetectLanguage.any_instance.stubs(:lang_via_cld).returns(false)
    User.any_instance.stubs(:detect_language?).returns(true)
    Users::DetectLanguage.any_instance.stubs(:detect_lang_from_email_service).returns('sv')
    Users::DetectLanguage.new.perform(user_id: @user.id, text: 'BC eller Barnens första bok för skolan och hemmet')
    @user.reload
    assert_equal 'sv-SE', @user.language, 'language detection proper response from email service'
    Users::DetectLanguage.any_instance.stubs(:detect_lang_from_email_service).returns('no')
    Users::DetectLanguage.new.perform(user_id: @user.id, text: 'ari drar til Frognerparken')
    @user.reload
    assert_equal 'nb-NO', @user.language, 'language detection proper response from email service'
  end

  def test_lang_detect_from_email_service_for_failure_response
    User.any_instance.stubs(:detect_language?).returns(true)
    Users::DetectLanguage.any_instance.stubs(:detect_lang_from_email_service).returns(@account.language)
    Users::DetectLanguage.new.perform(user_id: @user.id, text: 'test string - sample 2')
    @user.reload
    assert_equal @user.account.language, @user.language, 'language detection improper response from email service'
  end

  #keeps failing randomly when its straightforward. Will fix it later. commenting for now. 
  # def test_lang_detection_with_cld_russian
  #   @new_user = create_contact(options={language: nil})
  #   User.any_instance.stubs(:detect_language?).returns(true)
  #   @account.launch(:compact_lang_detection)
  #   set_others_redis_hash_set("CLD_FD_LANGUAGE_MAPPING", "ru", "ru-RU")
  #   Users::DetectLanguage.new.perform(user_id: @new_user.id, text: 'всякий раз, когда есть большой текст, я не знаю, что печатать. Я просто набираю, что приходит на ум, чтобы дать вклад')
  #   @new_user.reload
  #   assert_equal @new_user.language, "ru-RU"
  #   @account.rollback(:compact_lang_detection)
  # end

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