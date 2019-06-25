require_relative '../../test_helper'

module Widget
  class TicketsControllerTest < ActionController::TestCase
    include ApiTicketsTestHelper
    include HelpWidgetsTestHelper

    def setup
      super
      @account.launch :help_widget
      @account.add_feature(:anonymous_tickets)
      @widget = create_widget
      @request.env['HTTP_X_WIDGET_ID'] = @widget.id
      @client_id = UUIDTools::UUID.timestamp_create.hexdigest
      @request.env['HTTP_X_CLIENT_ID'] = @client_id
      before_all
      log_out
      controller.class.any_instance.stubs(:api_current_user).returns(nil)
    end

    @@before_all_run = false

    def before_all
      @account.sections.map(&:destroy)
      return if @@before_all_run
      toggle_required_attribute(Helpdesk::TicketField.where(required_in_portal: true))
      # editable in portal custom_fields
      create_custom_field('test_custom_text_1_editable', 'text', '05', false, false, true)
      # not editable in portal custom_fields
      create_custom_field('test_custom_text_2_not_editable', 'text', '05', false, false, false)
      @@before_all_run = true
    end

    def teardown
      super
      controller.class.any_instance.unstub(:api_current_user)
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
      post :create, construct_params({ version: 'widget' }, params)
      assert_response 400
    end

    def test_create_with_only_description
      params = { description: Faker::Lorem.paragraph }
      post :create, construct_params({ version: 'widget' }, params)
      assert_response 400
    end

    def test_create_with_only_requester_name
      params = { name: Faker::Name.name }
      post :create, construct_params({ version: 'widget' }, params)
      assert_response 400
    end

    def test_create_with_required_fields
      # email, description
      params = { email: Faker::Internet.email, description: Faker::Lorem.paragraph }
      post :create, construct_params({ version: 'widget' }, params)
      t = Helpdesk::Ticket.last
      result = parse_response(@response.body)
      assert_response 201
      match_json(id: t.display_id)
    end

    def test_create_without_help_widget_launch
      Account.any_instance.stubs(:help_widget_enabled?).returns(false)
      params = { email: Faker::Internet.email, description: Faker::Lorem.paragraph }
      post :create, construct_params({ version: 'widget' }, params)
      assert_response 403
      Account.any_instance.unstub(:help_widget_enabled?)
    end

    def test_create_with_attachment_ids
      attachment_ids = []
      attachment_ids << create_attachment(attachable_type: 'WidgetDraft', attachable_id: @widget.id, description: @client_id).id
      params = { email: Faker::Internet.email, description: Faker::Lorem.paragraph }
      params[:attachment_ids] = attachment_ids
      post :create, construct_params({ version: 'widget' }, params)
      t = Helpdesk::Ticket.last
      result = parse_response(@response.body)
      assert_response 201
      match_json(id: t.display_id)
      assert t.attachments.size == 1
    end

    def test_create_with_invalid_attachable
      attachment_ids = []
      attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      params = { email: Faker::Internet.email, description: Faker::Lorem.paragraph }
      params[:attachment_ids] = attachment_ids
      post :create, construct_params({ version: 'widget' }, params)
      assert_response 400
      match_json(validation_error_pattern(bad_request_error_pattern(:attachment_ids, "There are no records matching the ids: '#{attachment_ids.first}'", code: 'invalid_value')))
    end

    def test_create_with_invalid_client_id
      attachment_ids = []
      attachment_ids << create_attachment(attachable_type: 'WidgetDraft', attachable_id: @widget.id, description: '1234').id
      params = { email: Faker::Internet.email, description: Faker::Lorem.paragraph }
      params[:attachment_ids] = attachment_ids
      post :create, construct_params({ version: 'widget' }, params)
      assert_response 400
      match_json(validation_error_pattern(bad_request_error_pattern(:attachment_ids, "There are no records matching the ids: '#{attachment_ids.first}'", code: 'invalid_value')))
    end

    def test_create_with_invalid_attachment_ids
      params = { email: Faker::Internet.email, description: Faker::Lorem.paragraph }
      params[:attachment_ids] = [100]
      post :create, construct_params({ version: 'widget' }, params)
      t = Helpdesk::Ticket.last
      result = parse_response(@response.body)
      assert_response 400
      match_json(validation_error_pattern(bad_request_error_pattern(:attachment_ids, "There are no records matching the ids: '100'", code: 'invalid_value')))
    end

    def test_create_with_attachment_invalid_widget_id
      attachment_ids = []
      attachment_ids << create_attachment(attachable_type: 'WidgetDraft', attachable_id: 1234, description: @client_id).id
      params = { email: Faker::Internet.email, description: Faker::Lorem.paragraph }
      params[:attachment_ids] = attachment_ids
      post :create, construct_params({ version: 'widget' }, params)
      assert_response 400
      match_json(validation_error_pattern(bad_request_error_pattern(:attachment_ids, "There are no records matching the ids: '#{attachment_ids.first}'", code: 'invalid_value')))
    end

    def test_create_with_partial_required_fields
      params = { email: Faker::Internet.email }
      post :create, construct_params({ version: 'widget' }, params)
      assert_response 400
      match_json([bad_request_error_pattern('description', :field_validation_for_widget, code: :missing_field)])
    end

    def test_create_with_invalid_widget_id
      params = { email: Faker::Internet.email, description: Faker::Lorem.paragraph, subject: Faker::Lorem.words(10).join(' ') }
      @request.env['HTTP_X_WIDGET_ID'] = Faker::Number.number(6)
      post :create, construct_params({ version: 'widget' }, params)
      assert_response 400
      match_json(request_error_pattern(:invalid_help_widget, 'invalid_help_widget'))
    end

    def test_create_with_no_widget_id
      params = { email: Faker::Internet.email, description: Faker::Lorem.paragraph, subject: Faker::Lorem.words(10).join(' ') }
      @request.env.delete('HTTP_X_WIDGET_ID')
      post :create, construct_params({ version: 'widget' }, params)
      assert_response 400
      match_json(request_error_pattern(:widget_id_not_given))
    end

    # Ticket fields form widget ticket create test cases
    def test_create_with_product_id
      @request.env['HTTP_X_WIDGET_ID'] = create_widget(form_type: 2).id
      product = create_product
      product_field = Helpdesk::TicketField.where(name: 'product').first
      product_field.editable_in_portal = true
      product_field.save
      params = { email: Faker::Internet.email, description: Faker::Lorem.paragraph, product_id: product.id, status: 2, responder_id: @agent.id, subject: Faker::Name.name }
      post :create, construct_params({ version: 'widget' }, params)
      t = Helpdesk::Ticket.last
      assert_response 201
      match_json(id: t.display_id)
      assert t.product.id == product.id
    end

    def test_create_without_default_fields_required
      Account.any_instance.stubs(:unique_contact_identifier_enabled?).returns(false)
      settings = settings_hash(form_type: 2)
      toggle_required_attribute(Helpdesk::TicketField.where(required_in_portal: true, default: 1))
      @request.env['HTTP_X_WIDGET_ID'] = create_widget(settings: settings).id
      post :create, construct_params({ version: 'widget' }, {})
      assert_response 400
      match_json([bad_request_error_pattern('requester_id', :fill_a_mandatory_field, field_names: 'requester_id, phone, email, twitter_id, facebook_id')])
    ensure
      Account.any_instance.unstub(:unique_contact_identifier_enabled?)
    end

    def test_create_with_all_default_fields_required_invalid
      settings = settings_hash(form_type: 2)
      @request.env['HTTP_X_WIDGET_ID'] = create_widget(settings: settings).id
      default_non_required_fields = Helpdesk::TicketField.where(required_in_portal: false, default: 1)
      toggle_required_attribute(default_non_required_fields)
      non_editable_fields = Helpdesk::TicketField.where(editable_in_portal: false, default: 1)
      toggle_editable_in_portal(non_editable_fields)
      params_hash = {
        subject: 1,
        description: 1,
        product_id: 'y',
        responder_id: 'x',
        status: 999,
        email: Faker::Internet.email
      }
      post :create, construct_params({ version: 'widget' }, params_hash)
      ticket_type_list = "Question,Incident,Problem,Feature Request,Refund"
      service_task = Admin::AdvancedTicketing::FieldServiceManagement::Constant::SERVICE_TASK_TYPE
      ticket_type_list << ",#{service_task}" if Account.current.picklist_values.map(&:value).include?(service_task)
      match_json([bad_request_error_pattern('description', :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Integer'),
                  bad_request_error_pattern('subject',  :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Integer'),
                  bad_request_error_pattern('responder_id', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: 'String'),
                  bad_request_error_pattern('product_id', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: 'String'),
                  bad_request_error_pattern('status', :not_included, list: '2,3,4,5,6,7,8')])
      assert_response 400
      toggle_required_attribute(default_non_required_fields)
    end

    def test_create_without_custom_fields_required
      settings = settings_hash(form_type: 2)
      @request.env['HTTP_X_WIDGET_ID'] = create_widget(settings: settings).id
      params_hash = { email: Faker::Internet.email, description: Faker::Lorem.paragraph, responder_id: @agent.id, subject: Faker::Lorem.words(10).join(' '),
                      status: 2}
      custom_fields = Helpdesk::TicketField.where(name: [@custom_field_names])
      toggle_required_attribute(custom_fields)
      post :create, construct_params({ version: 'widget' }, params_hash)
      toggle_required_attribute(custom_fields)
      t = @account.tickets.last
      assert_response 201
      match_json(id: t.display_id)
    end

    def test_create_with_meta_headers
      settings = settings_hash(form_type: 1)
      @request.env['HTTP_X_WIDGET_ID'] = create_widget(settings: settings).id
      @request.env['HTTP_USER_AGENT'] = 'Freshdesk_Native'
      @request.env['HTTP_REFERER'] = 'http://ateam.freshdesk.com'
      params = { email: Faker::Internet.email, description: Faker::Lorem.paragraph }
      post :create, construct_params({ version: 'widget' }, params)
      t = Helpdesk::Ticket.last
      assert_response 201
      match_json(id: t.display_id)
      t = @account.tickets.last
      meta_info = t.notes.find_by_source(Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['meta'])
      assert_not_equal({}, meta_info)
      meta_info = YAML.load(meta_info.body)
      assert_equal meta_info['user_agent'], @request.env['HTTP_USER_AGENT']
      assert_equal meta_info['referrer'], @request.env['HTTP_REFERER']
    end

    def test_create_with_meta_params
      settings = settings_hash(form_type: 1)
      @request.env['HTTP_X_WIDGET_ID'] = create_widget(settings: settings).id
      params = { email: Faker::Internet.email, description: Faker::Lorem.paragraph, meta: { user_agent: 'Freshdesk_Native', referrer: 'http://ateam.freshdesk.com' } }
      post :create, construct_params({ version: 'widget' }, params)
      t = Helpdesk::Ticket.last
      assert_response 201
      match_json(id: t.display_id)
      t = @account.tickets.last
      meta_info = t.notes.find_by_source(Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['meta'])
      assert_not_equal({}, meta_info)
      meta_info = YAML.load(meta_info.body)
      assert_equal meta_info['user_agent'], 'Freshdesk_Native'
      assert_equal meta_info['referrer'], 'http://ateam.freshdesk.com'
    end
    
    def test_create_with_whitelisted_domain_with_restricted_helpdesk_enabled
      @account.launch(:restricted_helpdesk)
      @account.features.restricted_helpdesk.create
      @account.helpdesk_permissible_domains.create(domain: 'restrictedhelpdesk.com')
      settings = settings_hash(form_type: 1)
      @request.env['HTTP_X_WIDGET_ID'] = create_widget(settings: settings).id
      params = { email: 'testwhitelist@restrictedhelpdesk.com', description: Faker::Lorem.paragraph }
      post :create, construct_params({ version: 'widget' }, params)
      t = Helpdesk::Ticket.last
      assert_response 201
      match_json(id: t.display_id)
    ensure
      @account.features.restricted_helpdesk.destroy
      @account.rollback(:restricted_helpdesk)
    end

    def test_create_with_incorrect_domain_with_restricted_helpdesk_enabled
      @account.launch(:restricted_helpdesk)
      @account.features.restricted_helpdesk.create
      @account.helpdesk_permissible_domains.create(domain: 'restrictedhelpdesk.com')
      settings = settings_hash(form_type: 1)
      @request.env['HTTP_X_WIDGET_ID'] = create_widget(settings: settings).id
      params = { email: "testemailuser@#{Faker::Internet.domain_name}", description: Faker::Lorem.paragraph }
      post :create, construct_params({ version: 'widget' }, params)
      assert_response 400
    ensure
      @account.features.restricted_helpdesk.destroy
      @account.rollback(:restricted_helpdesk)
    end

    def test_create_with_no_contact_form_and_predictive
      settings = settings_hash(contact_form: false, predictive_support: false)
      @request.env['HTTP_X_WIDGET_ID'] = create_widget(settings: settings).id
      params = { email: Faker::Internet.email, description: Faker::Lorem.paragraph }
      post :create, construct_params({ version: 'widget' }, params)
      assert_response 400
      match_json(request_error_pattern(:ticket_creation_not_allowed, 'ticket_creation_not_allowed'))
    end

    def test_create_with_editable_in_portal_fields_returns_success
      settings = settings_hash(form_type: 2)
      @request.env['HTTP_X_WIDGET_ID'] = create_widget(settings: settings).id
      params = { email: Faker::Internet.email, description: Faker::Lorem.paragraph, status: 2, subject: Faker::Lorem.words(10).join(' '), responder_id: @agent.id, custom_fields: { test_custom_text_1_editable: 'test' } }
      post :create, construct_params({ version: 'widget' }, params)
      t = Helpdesk::Ticket.last
      assert_response 201
      match_json(id: t.display_id)
    end

    def test_create_with_not_editable_in_portal_fields_returns_failure
      settings = settings_hash(form_type: 2)
      @request.env['HTTP_X_WIDGET_ID'] = create_widget(settings: settings).id
      params = { email: Faker::Internet.email, description: Faker::Lorem.paragraph, subject: Faker::Lorem.words(10).join(' '), custom_fields: { test_custom_text_2_not_editable: 'test' } }
      post :create, construct_params({ version: 'widget' }, params)
      assert_response 400
      match_json(validation_error_pattern(bad_request_error_pattern(:test_custom_text_2_not_editable, 'Unexpected/invalid field in request', code: 'invalid_field')))
    end
  end
end
