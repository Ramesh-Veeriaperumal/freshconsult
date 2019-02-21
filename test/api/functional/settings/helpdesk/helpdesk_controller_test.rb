require_relative '../../../test_helper'
module Settings
  class HelpdeskControllerTest < ActionController::TestCase
    include HelpdeskTestHelper

    def setup
      super
      @account = Account.first.make_current
      @previous_primary = @account.main_portal.language
      @previous_supported = @account.account_additional_settings.supported_languages
      @previous_portal = @account.account_additional_settings.additional_settings[:portal_languages]
      @previous_feature = @account.features_included?(:enable_multilingual)
      @previous_multilanguage = @account.features_included?(:multi_language)
      @account.features.enable_multilingual.destroy
      @account.features.multi_language.create
      @account.save
    end

    def teardown
      @account.main_portal.language = @previous_primarys
      @account.account_additional_settings.supported_languages = @previous_supported
      @account.account_additional_settings.additional_settings[:portal_languages] = @previous_portal
      @account.features.enable_multilingual.create if @previous_feature
      @account.features.multi_language.destroy unless @previous_multilanguage
      @account.save
    end

    def test_feature
      Account.any_instance.stubs(:features_included?).with(:enable_multilingual).returns(true)
      put :update, construct_params('primary_language' => 'he', 'supported_languages' => ['ru-RU'], 'portal_languages' => ['ru-RU'])
      match_json([bad_request_error_pattern('feature', :supported_previously_added)])
      assert_response 400
      Account.any_instance.unstub(:features_included?)
    end

    def test_helpdesk_index
      get :index, controller_params
      assert_response 200
      match_json(helpdesk_languages_pattern(@account))
    end

    def test_helpdesk_update
      put :update, construct_params('primary_language' => 'en')
      assert_response 200
      assert_equal @account.main_portal.language, 'en'
    end

    def test_supported_language_already_primary
      put :update, construct_params('primary_language' => 'en', 'supported_languages' => ['en', 'ru-RU'], 'portal_languages' => ['ru-RU'])
      assert_response 400
      match_json([bad_request_error_pattern('supported_languages', :supported_language_primary)])
    end

    def test_update_invalid_language
      put :update, construct_params('primary_language' => 'en', 'supported_languages' => ['ca', 'invalid_support_language'], 'portal_languages' => ['ca'])
      assert_response 400
      match_json([bad_request_error_pattern('supported_languages', :invalid_language, languages: 'invalid_support_language')])
      put :update, construct_params('primary_language' => 'invalid_primary_language', 'supported_languages' => ['ca'], 'portal_languages' => ['ca'])
      assert_response 400
      match_json([bad_request_error_pattern('primary_language', :invalid_language, languages: 'invalid_primary_language')])
    end

    def test_portal_language_not_supported
      @account.account_additional_settings.supported_languages = ['ru-RU', 'fr']
      @account.account_additional_settings.additional_settings[:portal_languages] = ['fr']
      @account.save
      put :update, construct_params('supported_languages' => ['ru-RU'])
      assert_response 200
      assert_equal @account.portal_languages, []
    end

    def test_primary_or_supported
      @account.main_portal.language = 'en'
      @account.account_additional_settings.supported_languages = ['ru-RU', 'fr']
      @account.account_additional_settings.additional_settings[:portal_languages] = ['fr']
      @account.save
      put :update, construct_params('primary_language' => 'ca', 'supported_languages' => ['ru-RU', 'fr', 'he'])
      assert_response 400
    end

    def test_multi_language_feature
      @account.main_portal.language = 'en'
      @account.account_additional_settings.supported_languages = ['ru-RU', 'fr']
      @account.account_additional_settings.additional_settings[:portal_languages] = ['fr']
      @account.save
      Account.any_instance.stubs(:features_included?).with(:multi_language).returns(false)
      put :update, construct_params('supported_languages' => ['ru-RU', 'fr', 'he'])
      assert_response 400
      Account.any_instance.unstub(:features_included?)
    end

    def test_wrong_portal_language_add
      @account.main_portal.language = 'en'
      @account.account_additional_settings.supported_languages = ['fr']
      @account.account_additional_settings.additional_settings[:portal_languages] = ['fr']
      @account.save
      put :update, construct_params('portal_languages' => ['random_languages'])
      assert_response 400
      match_json([bad_request_error_pattern('portal_languages', :not_included, list: @account.supported_languages)])
    end

    def test_runtime_error
      Settings::HelpdeskValidation.any_instance.stubs(:valid?).returns(true)
      put :update, construct_params('primary_language' => 'sadf', 'supported_languages' => ['ca'], 'portal_languages' => ['essfasdf'])
      assert_response 400
      Settings::HelpdeskValidation.any_instance.unstub(:valid?)
    end
  end
end
