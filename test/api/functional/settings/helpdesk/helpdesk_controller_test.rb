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

    def test_helpdesk_index_without_privilege
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(false)
      get :index, controller_params
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    ensure
      User.any_instance.unstub(:privilege?)
    end

    def test_helpdesk_update
      put :update, construct_params('primary_language' => 'en')
      assert_response 200
      assert_equal @account.main_portal.language, 'en'
    end

    def test_helpdesk_update_portal_language_with_help_widget
      account_additional_settings = @account.account_additional_settings
      account_additional_settings.supported_languages = ['ru-RU']
      account_additional_settings.save
      Account.any_instance.stubs(:help_widget_enabled?).returns(true)
      help_widget = @account.help_widgets.create
      HelpWidget::UploadConfig.jobs.clear
      assert_equal HelpWidget::UploadConfig.jobs.size, 0
      put :update, construct_params('portal_languages' => ['ru-RU'])
      assert_response 200
      assert_equal @account.account_additional_settings.additional_settings[:portal_languages], ['ru-RU']
      widget_json_upload_ids = HelpWidget::UploadConfig.jobs.map { |a| a['args'].first['widget_id'] }
      assert_include widget_json_upload_ids, help_widget.id
    ensure
      Account.any_instance.unstub(:help_widget_enabled?)
      help_widget.destroy
    end

    def test_helpdesk_update_portal_language_without_help_widget
      @account.help_widgets.destroy_all
      help_widget = @account.help_widgets.create
      Account.any_instance.stubs(:help_widget_enabled?).returns(false)
      HelpWidget::UploadConfig.jobs.clear
      put :update, construct_params('primary_language' => 'en', 'supported_languages' => ['ru-RU'], 'portal_languages' => ['ru-RU'])
      assert_response 200
      assert_equal @account.account_additional_settings.additional_settings[:portal_languages], ['ru-RU']
      widget_json_upload_ids = HelpWidget::UploadConfig.jobs.map { |a| a['args'].first['widget_id'] }
      assert widget_json_upload_ids.exclude?(help_widget.id)
    end

    def test_helpdesk_update_primary_language_with_help_widget
      Account.any_instance.stubs(:help_widget_enabled?).returns(true)
      help_widget = @account.help_widgets.create
      HelpWidget::UploadConfig.jobs.clear
      assert_equal HelpWidget::UploadConfig.jobs.size, 0
      @account.add_feature(:autofaq)
      @account.add_feature(:botflow)
      put :update, construct_params('primary_language' => 'ca')
      assert_response 200
      assert_equal @account.main_portal.language, 'ca'
      widget_json_upload_ids = HelpWidget::UploadConfig.jobs.map { |a| a['args'].first['widget_id'] }
      assert_include widget_json_upload_ids, help_widget.id
      assert_equal @account.autofaq_enabled?, false
      assert_equal @account.botflow_enabled?, false
    ensure
      Account.any_instance.unstub(:help_widget_enabled?)
      help_widget.destroy
    end

    def test_helpdesk_update_primary_language_without_help_widget
      @account.help_widgets.destroy_all
      help_widget = @account.help_widgets.create
      Account.any_instance.stubs(:help_widget_enabled?).returns(false)
      HelpWidget::UploadConfig.jobs.clear
      put :update, construct_params('primary_language' => 'en')
      assert_response 200
      assert_equal @account.account_additional_settings.additional_settings[:portal_languages], ['ru-RU']
      widget_json_upload_ids = HelpWidget::UploadConfig.jobs.map { |a| a['args'].first['widget_id'] }
      assert widget_json_upload_ids.exclude?(help_widget.id)
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

    def test_update_invalid_language_in_production
      Rails.env.stubs(:production?).returns(true)
      put :update, construct_params('primary_language' => 'en', 'supported_languages' => ['ca', 'test-ui'], 'portal_languages' => ['ca'])
      assert_response 400
      match_json([bad_request_error_pattern('supported_languages', :invalid_language, languages: 'test-ui')])
      put :update, construct_params('primary_language' => 'invalid_primary_language', 'supported_languages' => ['ca'], 'portal_languages' => ['ca'])
      assert_response 400
      match_json([bad_request_error_pattern('primary_language', :invalid_language, languages: 'invalid_primary_language')])
    ensure
      Rails.env.unstub(:production?)
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
