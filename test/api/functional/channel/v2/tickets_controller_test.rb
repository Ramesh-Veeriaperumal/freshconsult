require_relative '../../../test_helper'

module Channel::V2
  class TicketsControllerTest < ActionController::TestCase
    include TicketsTestHelper

    CUSTOM_FIELDS = %w[number checkbox decimal text paragraph dropdown country state city date].freeze

    def setup
      super
      before_all
    end

    @@before_all_run = false

    def before_all
      @account.sections.map(&:destroy)
      return if @@before_all_run
      @account.ticket_fields.custom_fields.each(&:destroy)
      Helpdesk::TicketStatus.find(2).update_column(:stop_sla_timer, false)
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

    def requester
      user = User.find { |x| x.id != @agent.id && x.helpdesk_agent == false && x.deleted == 0 && x.blocked == 0 } || add_new_user(@account)
      user
    end

    def ticket
      ticket = Helpdesk::Ticket.where('source != ?', 10).last || create_ticket(ticket_params_hash)
      ticket
    end

    def ticket_params_hash
      cc_emails = [Faker::Internet.email, Faker::Internet.email]
      subject = Faker::Lorem.words(10).join(' ')
      description = Faker::Lorem.paragraph
      email = Faker::Internet.email
      tags = [Faker::Name.name, Faker::Name.name]
      @create_group ||= create_group_with_agents(@account, agent_list: [@agent.id])
      params_hash = { email: email, cc_emails: cc_emails, description: description, subject: subject,
                      priority: 2, status: 3, type: 'Problem', responder_id: @agent.id, source: 1, tags: tags,
                      due_by: 14.days.since.iso8601, fr_due_by: 1.day.since.iso8601, group_id: @create_group.id }
      params_hash
    end

    def test_create_with_created_at_updated_at
      created_at = updated_at = Time.now
      params = {
        requester_id: requester.id, status: 2, priority: 2,
        subject: Faker::Name.name, description: Faker::Lorem.paragraph,
        'created_at' => created_at, 'updated_at' => updated_at
      }
      Account.any_instance.stubs(:shared_ownership_enabled?).returns(false)
      post :create, construct_params({ version: 'private' }, params)
      assert_response 201
      t = Helpdesk::Ticket.last
      match_json(ticket_pattern(params, t))
      match_json(ticket_pattern({}, t))
      assert (t.created_at - created_at).to_i == 0
      assert (t.updated_at - updated_at).to_i == 0
    end

    def test_create_with_pending_since
      created_at = updated_at = (Time.now - 10.days)
      pending_since = (Time.now - 5.days)
      params = {
        requester_id: requester.id, status: 3, priority: 2,
        subject: Faker::Name.name, description: Faker::Lorem.paragraph,
        pending_since: pending_since, 'created_at' => created_at,
        'updated_at' => updated_at
      }
      Account.any_instance.stubs(:shared_ownership_enabled?).returns(false)
      Rails.logger.debug 'Creating ticket 1'
      post :create, construct_params({ version: 'private' }, params)
      Rails.logger.debug 'Creating ticket 2'
      assert_response 201
      t = Helpdesk::Ticket.last
      match_json(ticket_pattern(params, t))
      match_json(ticket_pattern({}, t))
      assert (t.pending_since - pending_since).to_i == 0
    end

    def test_create_with_on_state_time
      on_state_time = 100
      params = {
        requester_id: requester.id, status: 2, priority: 2,
        subject: Faker::Name.name, description: Faker::Lorem.paragraph,
        on_state_time: on_state_time
      }
      Account.any_instance.stubs(:shared_ownership_enabled?).returns(false)
      post :create, construct_params({ version: 'private' }, params)
      assert_response 201
      t = Helpdesk::Ticket.last
      match_json(ticket_pattern(params, t))
      match_json(ticket_pattern({}, t))
      assert t.on_state_time - on_state_time == 0
    end

    def test_create_with_on_state_time_as_string
      on_state_time = 100
      params = {
        requester_id: requester.id.to_s, status: '2', priority: '2',
        subject: Faker::Name.name, description: Faker::Lorem.paragraph,
        on_state_time: on_state_time.to_s
      }
      Account.any_instance.stubs(:shared_ownership_enabled?).returns(false)
      @request.env['CONTENT_TYPE'] = 'multipart/form-data'
      post :create, construct_params({ version: 'private' }, params)
      assert_response 201
      t = Helpdesk::Ticket.last
      match_json(ticket_pattern(params.merge(status: 2, priority: 2, requester_id: t.requester_id), t))
      match_json(ticket_pattern({}, t))
      assert t.on_state_time - on_state_time == 0
    end

    def test_create_with_closed_at
      created_at = Time.now - 10.days
      updated_at = Time.now - 10.days
      closed_at = Time.now - 5.days
      params = {
        requester_id: requester.id, status: 5, priority: 2,
        subject: Faker::Name.name, description: Faker::Lorem.paragraph,
        'created_at' => created_at, 'updated_at' => updated_at, 'closed_at' => closed_at
      }
      Account.any_instance.stubs(:shared_ownership_enabled?).returns(false)
      post :create, construct_params({ version: 'private' }, params)
      assert_response 201
      t = Helpdesk::Ticket.last
      match_json(ticket_pattern(params, t))
      match_json(ticket_pattern({}, t))
      assert (t.closed_at - closed_at).to_i == 0
    end

    def test_update_with_closed_at
      t = create_ticket
      t.update_attributes(created_at: Time.now - 10.days, updated_at: Time.now - 10.days)
      t = t.reload
      closed_at = Time.now - 1.day
      params = {
        status: 5, priority: 2, source: 2, type: 'Question',
        closed_at: closed_at
      }
      Account.any_instance.stubs(:shared_ownership_enabled?).returns(false)
      _params = construct_params({ id: t.display_id, version: 'private' }, params)
      put :update, _params
      assert_response 200
      t = Helpdesk::Ticket.last
      match_json(update_ticket_pattern(params, t))
      match_json(update_ticket_pattern({}, t))
      assert (t.closed_at - closed_at).to_i == 0
    end

    def test_ticket_close_after_reopened
      t = create_ticket(status: 5)
      before_reopen_closed_at = t.closed_at
      # Reopening a closed ticket
      put :update, construct_params({ id: t.display_id, version: 'private' }, status: 2, priority: 2, source: 2)
      assert_response 200
      t = Helpdesk::Ticket.last
      assert t.status == 2
      # Closing it again
      closed_at = Time.now
      put :update, construct_params({ id: t.display_id, version: 'private' }, status: 5, priority: 2, source: 2)
      assert_response 200
      t = Helpdesk::Ticket.last
      after_close_closed_at = t.closed_at
      assert t.status == 5
      assert before_reopen_closed_at != after_close_closed_at
      assert (t.closed_at - closed_at).to_i == 0
    end

    def test_ticket_create_with_import_properties
      created_at = Time.now - 10.days
      updated_at = Time.now - 10.days
      current_time = Time.now
      params = {
        requester_id: requester.id, status: 5, priority: 2,
        subject: Faker::Name.name, description: Faker::Lorem.paragraph,
        'created_at' => created_at, 'updated_at' => updated_at,
        'opened_at' => current_time, 'first_response_time' => current_time,
        'first_assigned_at' => current_time, 'assigned_at' => current_time,
        'requester_responded_at' => current_time, 'agent_responded_at' => current_time,
        'status_updated_at' => current_time, 'sla_timer_stopped_at' => current_time,
        'avg_response_time_by_bhrs' => 100, 'resolution_time_by_bhrs' => 100,
        'inbound_count' => 2, 'outbound_count' => 2, 'group_escalated' => true,
        'first_resp_time_by_bhrs' => 100, 'avg_response_time' => 100,
        'deleted' => true, 'spam' => false, 'display_id' => 10_000
      }
      Account.any_instance.stubs(:shared_ownership_enabled?).returns(false)
      post :create, construct_params({ version: 'private' }, params)
      assert_response 201
      t = Helpdesk::Ticket.last
      match_json(ticket_pattern(params, t))
      match_json(ticket_pattern({}, t))
    end

    def test_ticket_create_with_invalid_import_properties
      created_at = Time.now - 10.days
      updated_at = Time.now - 10.days
      current_time = '2018-08-08 08:08:08'
      display_id = (Account.current.tickets.last.display_id || 0) + 1
      params = {
        requester_id: requester.id, status: 5, priority: 2,
        subject: Faker::Name.name, description: Faker::Lorem.paragraph,
        'created_at' => created_at, 'updated_at' => updated_at,
        'opened_at' => current_time, 'first_response_time' => current_time,
        'first_assigned_at' => current_time, 'assigned_at' => current_time,
        'requester_responded_at' => current_time, 'agent_responded_at' => current_time,
        'status_updated_at' => current_time, 'sla_timer_stopped_at' => current_time,
        'avg_response_time_by_bhrs' => 'test', 'resolution_time_by_bhrs' => 'test',
        'inbound_count' => 'test', 'outbound_count' => 'test', 'group_escalated' => 1,
        'first_resp_time_by_bhrs' => 'test', 'avg_response_time' => 'test',
        'deleted' => 1, 'spam' => 1, 'display_id' => display_id
      }
      Account.any_instance.stubs(:shared_ownership_enabled?).returns(false)
      post :create, construct_params({ version: 'private' }, params)
      match_json([
                   bad_request_error_pattern('opened_at', :invalid_date, accepted: 'combined date and time ISO8601'),
                   bad_request_error_pattern('first_response_time', :invalid_date, accepted: 'combined date and time ISO8601'),
                   bad_request_error_pattern('first_assigned_at', :invalid_date, accepted: 'combined date and time ISO8601'),
                   bad_request_error_pattern('assigned_at', :invalid_date, accepted: 'combined date and time ISO8601'),
                   bad_request_error_pattern('requester_responded_at', :invalid_date, accepted: 'combined date and time ISO8601'),
                   bad_request_error_pattern('agent_responded_at', :invalid_date, accepted: 'combined date and time ISO8601'),
                   bad_request_error_pattern('status_updated_at', :invalid_date, accepted: 'combined date and time ISO8601'),
                   bad_request_error_pattern('sla_timer_stopped_at', :invalid_date, accepted: 'combined date and time ISO8601'),
                   bad_request_error_pattern('inbound_count', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String),
                   bad_request_error_pattern('outbound_count', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String),
                   bad_request_error_pattern('resolution_time_by_bhrs', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String),
                   bad_request_error_pattern('first_resp_time_by_bhrs', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String),
                   bad_request_error_pattern('avg_response_time_by_bhrs', :datatype_mismatch, expected_data_type: 'Positive Number', prepend_msg: :input_received, given_data_type: String),
                   bad_request_error_pattern('avg_response_time', :datatype_mismatch, expected_data_type: 'Positive Number', prepend_msg: :input_received, given_data_type: String),
                   bad_request_error_pattern('group_escalated', :datatype_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: Integer),
                   bad_request_error_pattern('deleted', :datatype_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: Integer),
                   bad_request_error_pattern('spam', :datatype_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: Integer)
                 ])
      assert_response 400
    end

    def test_sla_calculation_if_created_at_current_time
      BusinessCalendar.any_instance.stubs(:holidays).returns([])
      current_time = Time.now.monday
      started_bhr_time = Time.gm(current_time.year, current_time.month, current_time.day, 8) # fix date so to calculate sla correctly
      created_at = updated_at = started_bhr_time.iso8601
      params = {
        requester_id: requester.id, status: 2, priority: 2,
        subject: Faker::Name.name, description: Faker::Lorem.paragraph,
        'created_at' => created_at, 'updated_at' => updated_at,
        import_id: 1000
      }
      Account.any_instance.stubs(:shared_ownership_enabled?).returns(false)
      post :create, construct_params({ version: 'private' }, params)
      assert_response 201
      t = Helpdesk::Ticket.last
      match_json(ticket_pattern(params, t))
      match_json(ticket_pattern({}, t))
      created_at = Time.parse created_at
      updated_at = Time.parse updated_at
      assert (t.created_at - created_at).to_i.zero?
      assert (t.updated_at - updated_at).to_i.zero?
      assert t.due_by - t.created_at == 1.day, "Expected due_by => #{t.due_by.inspect} to be equal to created time => #{t.created_at.inspect}"
      assert t.frDueBy - t.created_at == 8.hour, "Expected frDueBy => #{t.frDueBy.inspect} to be equal to created time => #{t.created_at.inspect}"
    end

    def test_sla_calculation_if_created_at_is_less_than_1month
      BusinessCalendar.any_instance.stubs(:holidays).returns([])
      current_time = Time.now.monday
      started_bhr_time = Time.gm(current_time.year, current_time.month, current_time.day, 8) # fix date so to calculate sla correctly
      created_at = updated_at = (started_bhr_time - 7.day).iso8601
      params = {
        requester_id: requester.id, status: 2, priority: 2,
        subject: Faker::Name.name, description: Faker::Lorem.paragraph,
        'created_at' => created_at, 'updated_at' => updated_at,
        import_id: 1001
      }
      Account.any_instance.stubs(:shared_ownership_enabled?).returns(false)
      post :create, construct_params({ version: 'private' }, params)
      assert_response 201
      t = Helpdesk::Ticket.last
      match_json(ticket_pattern(params, t))
      match_json(ticket_pattern({}, t))
      created_at = Time.parse created_at
      updated_at = Time.parse updated_at
      assert (t.created_at - created_at).to_i.zero?
      assert (t.updated_at - updated_at).to_i.zero?
      assert t.due_by - t.created_at == 1.day, "Expected due_by => #{t.due_by.inspect} to be equal to created time => #{t.created_at.inspect}"
      assert t.frDueBy - t.created_at == 8.hour, "Expected frDueBy => #{t.frDueBy.inspect} to be equal to created time => #{t.created_at.inspect}"
    end

    def test_sla_calculation_if_created_at_is_greater_than_1month
      BusinessCalendar.any_instance.stubs(:holidays).returns([])
      current_time = Time.now.monday
      started_bhr_time = Time.gm(current_time.year, current_time.month, current_time.day, 8) # fix date so to calculate sla correctly
      created_at = updated_at = (started_bhr_time - 60.day).iso8601
      params = {
        requester_id: requester.id, status: 2, priority: 2,
        subject: Faker::Name.name, description: Faker::Lorem.paragraph,
        'created_at' => created_at, 'updated_at' => updated_at,
        import_id: 1002
      }
      Account.any_instance.stubs(:shared_ownership_enabled?).returns(false)
      post :create, construct_params({ version: 'private' }, params)
      assert_response 201
      t = Helpdesk::Ticket.last
      match_json(ticket_pattern(params, t))
      match_json(ticket_pattern({}, t))
      created_at = Time.parse created_at
      updated_at = Time.parse updated_at
      assert (t.created_at - created_at).to_i.zero?
      assert (t.updated_at - updated_at).to_i.zero?
      assert t.due_by - t.created_at == 31.day, "Expected due_by => #{t.due_by.inspect} should be 30 days ahead of created time => #{t.created_at.inspect}"
      assert t.frDueBy - t.created_at == 31.day, "Expected frDueBy => #{t.frDueBy.inspect} should be 30 days ahead of  created time => #{t.created_at.inspect}"
    end

    def test_create_with_required_custom_dropdown_field
      ticket_field = @account.ticket_fields.find_by_name('test_custom_dropdown_1')
      previous_required_field = ticket_field.required
      ticket_field.update_attributes(required: true)
      created_at = updated_at = Time.now
      params = {
          requester_id: requester.id, status: 2, priority: 2,
          subject: Faker::Name.name, description: Faker::Lorem.paragraph,
          'created_at' => created_at, 'updated_at' => updated_at
      }
      Account.any_instance.stubs(:shared_ownership_enabled?).returns(false)
      post :create, construct_params({ version: 'private' }, params)
      assert_response 201
      t = Helpdesk::Ticket.last
      match_json(ticket_pattern(params, t))
      match_json(ticket_pattern({}, t))
      assert (t.created_at - created_at).to_i == 0
      assert (t.updated_at - updated_at).to_i == 0
      ticket_field.update_attributes(required: previous_required_field)
    end

    def test_create_with_required_custom_dependent_field
      ticket_field = @account.ticket_fields.find_by_name('test_custom_country_1')
      previous_required_field = ticket_field.required
      ticket_field.update_attributes(required: true)
      created_at = updated_at = Time.now
      params = {
          requester_id: requester.id, status: 2, priority: 2,
          subject: Faker::Name.name, description: Faker::Lorem.paragraph,
          'created_at' => created_at, 'updated_at' => updated_at
      }
      Account.any_instance.stubs(:shared_ownership_enabled?).returns(false)
      post :create, construct_params({ version: 'private' }, params)
      assert_response 201
      t = Helpdesk::Ticket.last
      match_json(ticket_pattern(params, t))
      match_json(ticket_pattern({}, t))
      assert (t.created_at - created_at).to_i == 0
      assert (t.updated_at - updated_at).to_i == 0
      ticket_field.update_attributes(required: previous_required_field)
    end
  end
end
