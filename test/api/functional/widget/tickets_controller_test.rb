require_relative '../../test_helper'

module Widget
  class TicketsControllerTest < ActionController::TestCase
    include TicketsTestHelper
    include HelpWidgetsTestHelper

    def setup
      super
      before_all
      @request.env['HTTP_X_WIDGET_ID'] = create_widget.id
    end

    @@before_all_run = false

    def before_all
      @account.sections.map(&:destroy)
      return if @@before_all_run
      @account.ticket_fields.custom_fields.each(&:destroy)
      ticket_status = Helpdesk::TicketStatus.where(status_id: 2).first
      ticket_status.stop_sla_timer = false
      ticket_status.save
      @@ticket_fields = []
      @@custom_field_names = []
      @@ticket_fields << create_dependent_custom_field(%w[test_custom_country test_custom_state test_custom_city])
      @@ticket_fields << create_custom_field_dropdown('test_custom_dropdown', ['Get Smart', 'Pursuit of Happiness', 'Armaggedon'])
      @@choices_custom_field_names = @@ticket_fields.map(&:name)
      CUSTOM_FIELDS.each do |custom_field|
        next if %w[dropdown country state city].include?(custom_field)
        @@ticket_fields << create_custom_field("test_custom_#{custom_field}", custom_field)
        @@custom_field_names << @@ticket_fields.last.name
      end
      @account.launch :add_watcher
      @account.save
      @@before_all_run = true
    end

    def wrap_cname(params = {})
      { ticket: params }
    end

    def ticket_params_hash
      subject = Faker::Lorem.words(10).join(' ')
      description = Faker::Lorem.paragraph
      email = Faker::Internet.email
      agent_id = @agent.id
      @create_group ||= create_group_with_agents(@account, agent_list: [agent_id])
      params_hash = { email: email, description: description, subject: subject,
                      priority: 2, status: 2, type: 'Problem', responder_id: agent_id, group_id: @create_group.id }
      params_hash
    end

    # Simple form widget ticket create test cases
    def test_create_with_only_requester_email
      params = { email: Faker::Internet.email }
      post :create, construct_params({version: 'widget'}, params)
      assert_response 400
    end

    def test_create_with_only_description
      params = { description: Faker::Lorem.paragraph }
      post :create, construct_params({version: 'widget'}, params)
      assert_response 400
    end

    def test_create_with_only_requester_name
      params = { name: Faker::Name.name }
      post :create, construct_params({version: 'widget'}, params)
      assert_response 400
    end

    def test_create_with_required_fields # email, description
      params = { email: Faker::Internet.email, description: Faker::Lorem.paragraph}
      post :create, construct_params({version: 'widget'}, params)
      t = Helpdesk::Ticket.last
      result = parse_response(@response.body)
      assert_response 201
      match_json({id: t.display_id})
    end

    def test_create_with_partial_required_fields
      params = { email: Faker::Internet.email }
      post :create, construct_params({version: 'widget'}, params)
      assert_response 400
      match_json([bad_request_error_pattern('description', :field_validation_for_widget, code: :missing_field)])
    end

    def test_create_with_invalid_widget_id
      params = { email: Faker::Internet.email, description: Faker::Lorem.paragraph, subject: Faker::Lorem.words(10).join(' ') }
      @request.env['HTTP_X_WIDGET_ID'] = Faker::Number.number(6)
      post :create, construct_params({version: 'widget'}, params)
      assert_response 400
      match_json(request_error_pattern(:invalid_help_widget, 'invalid_help_widget'))
    end

    def test_create_with_no_widget_id
      params = { email: Faker::Internet.email, description: Faker::Lorem.paragraph, subject: Faker::Lorem.words(10).join(' ') }
      @request.env.delete('HTTP_X_WIDGET_ID')
      post :create, construct_params({version: 'widget'}, params)
      assert_response 400
      match_json(request_error_pattern(:widget_id_not_given))
    end

    # Ticket fields form widget ticket create test cases
    def test_create_with_product_id
      @request.env['HTTP_X_WIDGET_ID'] = create_widget({form_type: 2}).id
      product = create_product
      params = { email: Faker::Internet.email, description: Faker::Lorem.paragraph, product_id: product.id, status: 2, priority: 2, subject: Faker::Name.name }
      post :create, construct_params({version: 'widget'}, params)
      t = Helpdesk::Ticket.last
      assert_response 201
      match_json({id: t.display_id})
      assert t.product.id == product.id
    end

    def test_create_without_default_fields_required
      settings = settings_hash({form_type: 2})
      toggle_required_attribute(Helpdesk::TicketField.where(required_in_portal: true, default: 1))
      @request.env['HTTP_X_WIDGET_ID'] = create_widget({settings: settings}).id
      post :create, construct_params({version: 'widget'}, {})
      assert_response 400
      match_json([bad_request_error_pattern('requester_id', :fill_a_mandatory_field, field_names: 'requester_id, phone, email, twitter_id, facebook_id')])
    end

    def test_create_with_all_default_fields_required_invalid
      settings = settings_hash({form_type: 2})
      @request.env['HTTP_X_WIDGET_ID'] = create_widget({settings: settings}).id
      default_non_required_fields = Helpdesk::TicketField.where(required_in_portal: false, default: 1)
      toggle_required_attribute(default_non_required_fields)
      params_hash = {
        subject: 1,
        description: 1,
        group_id: 'z',
        product_id: 'y',
        responder_id: 'x',
        status: 999,
        priority: 999,
        type: 'Test',
        email: Faker::Internet.email,
      }
      post :create, construct_params({version: 'widget'}, params_hash)
      match_json([bad_request_error_pattern('description', :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Integer'),
                  bad_request_error_pattern('subject',  :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Integer'),
                  bad_request_error_pattern('group_id', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: 'String'),
                  bad_request_error_pattern('responder_id', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: 'String'),
                  bad_request_error_pattern('product_id', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: 'String'),
                  bad_request_error_pattern('priority', :not_included, list: '1,2,3,4'),
                  bad_request_error_pattern('status', :not_included, list: '2,3,4,5,6,7'),
                  bad_request_error_pattern('type', :not_included, list: 'Question,Incident,Problem,Feature Request,Refund')])
      assert_response 400
      toggle_required_attribute(default_non_required_fields)
    end

    def test_create_without_custom_fields_required
      settings = settings_hash({form_type: 2})
      @request.env['HTTP_X_WIDGET_ID'] = create_widget({settings: settings}).id
      params_hash = ticket_params_hash
      custom_fields = Helpdesk::TicketField.where(name: [@custom_field_names])
      toggle_required_attribute(custom_fields)
      post :create, construct_params({version: 'widget'}, params_hash)
      toggle_required_attribute(custom_fields)
      t = @account.tickets.last
      assert_response 201
      match_json({id: t.display_id})
    end
  end
end
