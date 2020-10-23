require_relative '../../test_helper'

module Channel
  class TicketsControllerTest < ActionController::TestCase
    include ApiTicketsTestHelper

    CUSTOM_FIELDS = %w[number checkbox decimal text paragraph dropdown country state city date].freeze

    VALIDATABLE_CUSTOM_FIELDS =  %w[number checkbox decimal text paragraph date].freeze

    CUSTOM_FIELDS_VALUES_INVALID = { 'number' => '1.90', 'decimal' => 'dd', 'checkbox' => 'iu', 'text' => Faker::Lorem.characters(300), 'paragraph' => 12_345, 'date' => '31-13-09' }.freeze

    ERROR_PARAMS = {
      'number' => [:datatype_mismatch, expected_data_type: 'Integer', prepend_msg: :input_received, given_data_type: String],
      'decimal' => [:datatype_mismatch, expected_data_type: 'Number'],
      'checkbox' => [:datatype_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String],
      'text' => [:'Has 300 characters, it can have maximum of 255 characters'],
      'paragraph' => [:datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer],
      'date' => [:invalid_date, accepted: 'yyyy-mm-dd']
    }.freeze

    def setup
      super
      before_all
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
      @@ticket_fields << create_dependent_custom_field(%w[test_custom_country test_custom_state test_custom_city], Random.rand(20..30))
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
      cc_emails = [Faker::Internet.email, Faker::Internet.email]
      subject = Faker::Lorem.words(10).join(' ')
      description = Faker::Lorem.paragraph
      email = Faker::Internet.email
      tags = [Faker::Name.name, Faker::Name.name]
      agent_id = @agent.id
      @create_group ||= create_group_with_agents(@account, agent_list: [agent_id])
      params_hash = { email: email, cc_emails: cc_emails, description: description, subject: subject,
                      priority: 2, status: 2, type: 'Problem', responder_id: agent_id, source: 1, tags: tags,
                      due_by: 14.days.since.iso8601, fr_due_by: 1.day.since.iso8601, group_id: @create_group.id }
      params_hash
    end

    def test_create_without_default_fields_required_except_requester
      params = { email: Faker::Internet.email }
      post :create, construct_params({version: 'channel'}, params)
      t = Helpdesk::Ticket.last
      match_json(ticket_pattern(params, t))
      match_json(ticket_pattern({}, t))
      result = parse_response(@response.body)
      assert_equal true, response.headers.include?('Location')
      assert_equal "http://#{@request.host}/api/v2/tickets/#{result['id']}", response.headers['Location']
      assert_response 201
    end

    def test_create_without_default_fields_required_except_requester_with_jwt_header
      params = { email: Faker::Internet.email }
      set_jwt_auth_header('zapier')
      post :create, construct_params({version: 'channel'}, params)
      t = Helpdesk::Ticket.last
      match_json(ticket_pattern(params, t))
      match_json(ticket_pattern({}, t))
      result = parse_response(@response.body)
      assert_equal true, response.headers.include?('Location')
      assert_equal "http://#{@request.host}/api/v2/tickets/#{result['id']}", response.headers['Location']
      assert_response 201
    end

    def test_create_without_requester_info
      params = {}
      post :create, construct_params({version: 'channel'}, params)
      assert_response 400
      match_json([bad_request_error_pattern('requester_id', :fill_a_mandatory_field, field_names: 'requester_id, phone, email, twitter_id, facebook_id')])
    end

    def test_create_with_illegal_value_for_custom_number_field_with_jwt_header
      params = ticket_params_hash.merge(custom_fields: {})
      params[:custom_fields]['test_custom_number'] = '123abcl33t'
      set_jwt_auth_header('zapier')
      create_custom_field('test_custom_number', 'number')
      post :create, construct_params({ version: 'channel' }, params)
      assert_response 400
    end

    def test_create_with_stringified_number_value_for_custom_number_field_with_jwt_header
      params = ticket_params_hash.merge(custom_fields: {})
      params[:custom_fields]['test_custom_number'] = '123'
      set_jwt_auth_header('zapier')
      create_custom_field('test_custom_number', 'number')
      post :create, construct_params({ version: 'channel' }, params)
      result = parse_response(@response.body)
      assert_equal true, response.headers.include?('Location')
      assert_equal "http://#{@request.host}/api/v2/tickets/#{result['id']}", response.headers['Location']
      assert_response 201
    end

    def test_create_with_integer_value_for_custom_number_field_with_jwt_header
      params = ticket_params_hash.merge(custom_fields: {})
      params[:custom_fields]['test_custom_number'] = 123
      set_jwt_auth_header('zapier')
      create_custom_field('test_custom_number', 'number')
      post :create, construct_params({ version: 'channel' }, params)
      result = parse_response(@response.body)
      assert_equal true, response.headers.include?('Location')
      assert_equal "http://#{@request.host}/api/v2/tickets/#{result['id']}", response.headers['Location']
      assert_response 201
    end

    def test_create_with_all_default_fields_required_invalid
      default_non_required_fields = Helpdesk::TicketField.where(required: false, default: 1)
      default_non_required_fields.map { |x| x.toggle!(:required) }
      params_hash = {
        subject: 1,
        description: 1,
        group_id: 'z',
        product_id: 'y',
        responder_id: 'x',
        status: 999,
        priority: 999,
        type: 'Test',
        email: Faker::Internet.email
      }
      post :create, construct_params({ version: 'channel' }, params_hash)
      ticket_type_list = 'Question,Incident,Problem,Feature Request,Refunds and Returns,Bulk orders,Refund'
      service_task = ::Admin::AdvancedTicketing::FieldServiceManagement::Constant::SERVICE_TASK_TYPE
      ticket_type_list << ",#{service_task}" if Account.current.picklist_values.map(&:value).include?(service_task)
      match_json([bad_request_error_pattern('description', :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Integer'),
                  bad_request_error_pattern('subject',  :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Integer'),
                  bad_request_error_pattern('group_id', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: 'String'),
                  bad_request_error_pattern('responder_id', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: 'String'),
                  bad_request_error_pattern('product_id', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: 'String'),
                  bad_request_error_pattern('priority', :not_included, list: '1,2,3,4'),
                  bad_request_error_pattern('status', :not_included, list: '2,3,4,5,6,7'),
                  bad_request_error_pattern('type', :not_included, list: ticket_type_list)])
      assert_response 400
    ensure
      default_non_required_fields.map { |x| x.toggle!(:required) }
    end

    def test_create_without_custom_fields_required
      params = ticket_params_hash
      Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: true)
      post :create, construct_params({version: 'channel'}, params)
      Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: false)
      match_json(ticket_pattern(params, Helpdesk::Ticket.last))
      match_json(ticket_pattern({}, Helpdesk::Ticket.last))
      result = parse_response(@response.body)
      assert_equal true, response.headers.include?('Location')
      assert_equal "http://#{@request.host}/api/v2/tickets/#{result['id']}", response.headers['Location']
      assert_response 201
    end

    def test_create_without_custom_fields_required_with_jwt_header
      params = ticket_params_hash
      Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: true)
      set_jwt_auth_header('zapier')
      post :create, construct_params({version: 'channel'}, params)
      Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: false)
      match_json(ticket_pattern(params, Helpdesk::Ticket.last))
      match_json(ticket_pattern({}, Helpdesk::Ticket.last))
      result = parse_response(@response.body)
      assert_equal true, response.headers.include?('Location')
      assert_equal "http://#{@request.host}/api/v2/tickets/#{result['id']}", response.headers['Location']
      assert_response 201
    end

    def test_create_ticket_with_freshchat_jwt_header_success
      params = ticket_params_hash
      params.delete(:tags)
      set_jwt_auth_header('freshchat')
      @controller.stubs(:api_current_user).returns(nil)
      post :create, construct_params({version: 'channel'}, params)
      assert_response 201
    ensure
      @controller.unstub(:api_current_user)
    end

    def test_create_ticket_with_freshchat_jwt_header_failure
      params = ticket_params_hash
      set_jwt_auth_header('zapier')
      @controller.stubs(:api_current_user).returns(nil)
      post :create, construct_params({ version: 'channel' }, params)
      assert_response 401
    ensure
      @controller.unstub(:api_current_user)
    end

    def test_create_with_custom_fields_required_invalid
      params = ticket_params_hash.merge(custom_fields: {})
      VALIDATABLE_CUSTOM_FIELDS.each do |custom_field|
        params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES_INVALID[custom_field]
      end
      post :create, construct_params({version: 'channel'}, params)
      assert_response 400
      pattern = []
      VALIDATABLE_CUSTOM_FIELDS.each do |custom_field|
        pattern << bad_request_error_pattern("custom_fields.test_custom_#{custom_field}", *(ERROR_PARAMS[custom_field]))
      end
      match_json(pattern)
    end

    def test_create_ticket_with_field_service_jwt_header_success
      params = ticket_params_hash
      params.delete(:tags)
      set_jwt_auth_header('field_service')
      post :create, construct_params({ version: 'channel' }, params)
      assert_response 201
    ensure
      @controller.unstub(:api_current_user)
    end

    def test_get_ticket_with_field_service_jwt_header_success
      params = ticket_params_hash
      params.delete(:tags)
      set_jwt_auth_header_for_field_service
      created_ticket = post :create, construct_params({ version: 'channel' }, params)
      parsed_ticket = JSON.parse(created_ticket.body)

      set_jwt_auth_header_for_field_service(user_id = parsed_ticket['responder_id'])
      get :show, controller_params(version: 'channel', id: parsed_ticket['id'])
      assert_response 200
    end

    def test_get_ticket_with_field_service_jwt_header_with_unauthorized_actor
      params = ticket_params_hash
      params.delete(:tags)
      set_jwt_auth_header_for_field_service
      created_ticket = post :create, construct_params({ version: 'channel' }, params)
      parsed_ticket = JSON.parse(created_ticket.body)

      added_agent = add_test_agent(@account, role: Role.find_by_name('Agent').id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])
      set_jwt_auth_header_for_field_service(user_id = added_agent.id)
      get :show, controller_params(version: 'channel', id: parsed_ticket['id'])
      assert_response 403
      match_json(
        code: 'access_denied',
        message: 'You are not authorized to perform this action.'
      )
    end

    def set_jwt_auth_header_for_field_service(user_id = nil)
      payload = { enc_payload: { 'account_id' => @account.id, 'timestamp' => Time.now.iso8601 } }
      payload[:actor] = user_id if user_id
      token = JWT.encode payload, CHANNEL_API_CONFIG[:field_service][:jwt_secret], 'HS256', source: 'field_service'
      request.env['X-Channel-Auth'] = token
    end
  end
end
