require_relative '../../test_helper'

module Widget
  class TicketFieldsControllerTest < ActionController::TestCase
    include TicketFieldsTestHelper
    include HelpWidgetsTestHelper
    include ::Admin::AdvancedTicketing::FieldServiceManagement::Util

    def setup
      super
      @widget = create_widget
      @request.env['HTTP_X_WIDGET_ID'] = @widget.id
      @client_id = UUIDTools::UUID.timestamp_create.hexdigest
      @request.env['HTTP_X_CLIENT_ID'] = @client_id
      current_product = @widget.product_id
      @account.launch :help_widget
      @account.add_feature(:anonymous_tickets)
      @current_portal = current_product ? @account.portals.find_by_product_id(current_product) : current_account.main_portal_from_cache
    end

    def wrap_cname(_params)
      remove_wrap_params
      {}
    end

    def test_index_ignores_pagination
      get :index, controller_params(per_page: 1, page: 2)
      assert_response 200
      assert JSON.parse(response.body).count > 1
    end

    def test_index
      get :index, controller_params
      assert_response 200
      assert JSON.parse(response.body).count > 1
    end

    def test_index_default_field_name
      get :index, controller_params
      assert_response 200
      parsed_response = JSON.parse(response.body)
      assert parsed_response.find { |x| x['name'] == 'email' }.present?
    end

    # def test_index_scoper
    #   skip('failures and errors 21')
    #   get :index, controller_params
    #   assert_response 200
    #   portal_ticket_fields = @current_portal.customer_editable_ticket_fields
    #   assert JSON.parse(response.body).count == portal_ticket_fields.count
    # end

    def test_index_with_invalid_widget_id
      @request.env['HTTP_X_WIDGET_ID'] = Faker::Number.number(6)
      get :index, controller_params
      assert_response 400
      match_json(request_error_pattern(:invalid_help_widget, 'invalid_help_widget'))
    end

    def test_index_with_contact_form_disabled
      @widget.settings[:components][:contact_form] = false
      @widget.save
      get :index, controller_params
      assert_response 200
      assert JSON.parse(response.body).count > 1
    end

    def test_index_without_help_widget_launch
      Account.any_instance.stubs(:all_launched_features).returns([])
      get :index, controller_params
      assert_response 403
      Account.any_instance.unstub(:all_launched_features)
    end

    def test_index_without_anonymous_tickets
      Account.any_instance.stubs(:features?).with(:anonymous_tickets).returns(false)
      get :index, controller_params
      assert_response 403
      Account.any_instance.unstub(:features?)
    end

    def test_index_with_choices
      get :index, controller_params
      assert_response 200
      assert JSON.parse(response.body).count > 1
    end

    def test_ticket_field_cache_miss_agent_with_account_language
      language = Account.current.try(:language)
      with_product = Account.current.main_portal
      stub_account_language(nil, language, with_product) do
        Widget::TicketFieldsController.any_instance.expects(response_cache_data: nil)
        get :index, controller_params(version: 'private', language: language)
        assert_response 200
        Widget::TicketFieldsController.any_instance.unstub(:response_cache_data)
      end
    end

    def test_ticket_field_cache_hit_agent_with_account_language
      language = Account.current.try(:language)
      with_product = Account.current.main_portal
      stub_account_language(nil, language, with_product) do
        cache_data = { 'test' => 'test' }
        Widget::TicketFieldsController.any_instance.stubs(:response_cache_data).returns(cache_data)
        Widget::TicketFieldsController.any_instance.expects(:load_objects).never
        get :index, controller_params(version: 'private', language: language)
        assert_response 200
        assert response.body.include?('test')
        Widget::TicketFieldsController.any_instance.unstub(:response_cache_data)
        Widget::TicketFieldsController.any_instance.unstub(:load_objects)
      end
    end

    def test_ticket_field_cache_hit_agent_with_account_language_with_main_portal
      Account.current.main_portal.make_current
      language = Account.current.try(:language)
      with_product = Account.current.main_portal
      stub_account_language(nil, language, with_product) do
        cache_data = { 'test' => 'test' }
        Widget::TicketFieldsController.any_instance.stubs(:response_cache_data).returns(cache_data)
        Widget::TicketFieldsController.any_instance.expects(:load_objects).never
        get :index, controller_params(version: 'private', language: language)
        assert_response 200
        assert response.body.include?('test')
        Widget::TicketFieldsController.any_instance.unstub(:response_cache_data)
        Widget::TicketFieldsController.any_instance.unstub(:load_objects)
      end
    end

    def test_ticket_field_cache_miss_agent_with_account_supported_language
      acc_supported_language = language = 'fr'
      with_product = Account.current.main_portal
      stub_account_language(acc_supported_language, language, with_product) do
        Widget::TicketFieldsController.any_instance.expects(response_cache_data: nil)
        get :index, controller_params(version: 'private', language: language)
        assert_response 200
        Widget::TicketFieldsController.any_instance.unstub(:response_cache_data)
      end
    end

    def test_ticket_field_cache_hit_agent_with_account_supported_language
      acc_supported_language = language = 'fr'
      with_product = Account.current.main_portal
      stub_account_language(acc_supported_language, language, with_product) do
        cache_data = { 'test' => 'test' }
        Widget::TicketFieldsController.any_instance.stubs(:response_cache_data).returns(cache_data)
        Widget::TicketFieldsController.any_instance.expects(:load_objects).never
        get :index, controller_params(version: 'private', language: language)
        assert_response 200
        assert response.body.include?('test')
        Widget::TicketFieldsController.any_instance.unstub(:response_cache_data)
        Widget::TicketFieldsController.any_instance.unstub(:load_objects)
      end
    end

    def test_ticket_field_cache_miss_agent_with_non_account_supported_language
      acc_supported_language = 'fr'
      language = 'da'
      with_product = Account.current.main_portal
      stub_account_language(acc_supported_language, language, with_product) do
        cache_data = { 'test': 'test' }
        Widget::TicketFieldsController.any_instance.stubs(:response_cache_data).returns(cache_data)
        get :index, controller_params(version: 'private', language: language)
        assert_response 400
        Widget::TicketFieldsController.any_instance.unstub(:response_cache_data)
      end
    end

    def test_ticket_field_cache_hit_with_language_not_present
      with_product = Account.current.main_portal
      stub_account_language(nil, nil, with_product) do
        cache_data = { 'test' => 'test' }
        Widget::TicketFieldsController.any_instance.stubs(:response_cache_data).returns(cache_data)
        Widget::TicketFieldsController.any_instance.expects(:load_objects).never
        get :index, controller_params(version: 'private')
        assert_response 200
        assert response.body.include?('test')
        Widget::TicketFieldsController.any_instance.unstub(:response_cache_data)
        Widget::TicketFieldsController.any_instance.unstub(:load_objects)
      end
    end

    private

      def ticket_field_cache_key(language, with_product = true)
        with_product ? format(MemcacheKeys::CUSTOMER_EDITABLE_TICKET_FIELDS_FULL, account_id: Account.current.id, language_code: language.to_s) :
                        format(MemcacheKeys::CUSTOMER_EDITABLE_TICKET_FIELDS_WITHOUT_PRODUCT, account_id: Account.current.id, language_code: language.to_s)
      end

      def stub_account_language(acc_supported_language = nil, lang = nil, with_product = true)
        Account.any_instance.stubs(:all_languages).returns([Account.current.language, acc_supported_language]) if acc_supported_language.present?
        language = Language.find_by_code(lang) || Language.find_by_code(I18n.locale)
        response_cache_key = ticket_field_cache_key(language, with_product) if Account.current.all_languages.include?(language.code)
        Widget::TicketFieldsController.any_instance.expects(:response_cache_key).returns(response_cache_key) if response_cache_key
        Widget::TicketFieldsController.any_instance.expects(:response_cache_key).returns(response_cache_key) if response_cache_key
        yield
        Widget::TicketFieldsController.any_instance.unstub(:response_cache_key)
        Account.any_instance.unstub(:all_languages)
      end
  end
end
