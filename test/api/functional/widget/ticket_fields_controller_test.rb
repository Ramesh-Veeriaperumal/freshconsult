require_relative '../../test_helper'

module Widget
  class TicketFieldsControllerTest < ActionController::TestCase
    include TicketFieldsTestHelper
    include HelpWidgetsTestHelper

    def setup
      super
      @widget = create_widget
      @request.env['HTTP_X_WIDGET_ID'] = @widget.id
      @client_id = UUIDTools::UUID.timestamp_create.hexdigest
      @request.env['HTTP_X_CLIENT_ID'] = @client_id
      current_product = @widget.product_id
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
      assert_response 400
      match_json(request_error_pattern(:contact_form_not_enabled, 'contact_form_not_enabled'))
    end
  end
end
