require_relative '../../test_helper'

module Pipe
  class TicketsControllerTest < ActionController::TestCase
    include ApiTicketsTestHelper

    CUSTOM_FIELDS = %w(number checkbox decimal text paragraph dropdown country state city date).freeze

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
      @@ticket_fields << create_dependent_custom_field(%w(test_custom_country test_custom_state test_custom_city))
      @@ticket_fields << create_custom_field_dropdown('test_custom_dropdown', ['Get Smart', 'Pursuit of Happiness', 'Armaggedon'])
      @@choices_custom_field_names = @@ticket_fields.map(&:name)
      CUSTOM_FIELDS.each do |custom_field|
        next if %w(dropdown country state city).include?(custom_field)
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
      @account.stubs(:skill_based_round_robin_enabled?).returns(false)
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
      @account.unstub(:skill_based_round_robin_enabled?)
    end

    def test_create_with_pending_since
      @account.stubs(:skill_based_round_robin_enabled?).returns(false)
      created_at = updated_at = (Time.now - 10.days)
      pending_since = (Time.now - 5.days)
      params = {
        requester_id: requester.id, status: 3, priority: 2,
        subject: Faker::Name.name, description: Faker::Lorem.paragraph,
        pending_since: pending_since, 'created_at' => created_at,
        'updated_at' => updated_at
      }
      Account.any_instance.stubs(:shared_ownership_enabled?).returns(false)
      post :create, construct_params({ version: 'private' }, params)
      assert_response 201
      t = Helpdesk::Ticket.last
      match_json(ticket_pattern(params, t))
      match_json(ticket_pattern({}, t))
      assert (t.pending_since - pending_since).to_i == 0
      @account.unstub(:skill_based_round_robin_enabled?)
    end

    def test_create_with_on_state_time
      @account.stubs(:skill_based_round_robin_enabled?).returns(false)
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
      @account.unstub(:skill_based_round_robin_enabled?)
    end

    def test_create_with_on_state_time_as_string
      @account.stubs(:skill_based_round_robin_enabled?).returns(false)
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
      @account.unstub(:skill_based_round_robin_enabled?)
    end

    def test_create_with_closed_at
      skip('Failure because of memcache issue. Raghav will fix it #FD-33639')
      @account.stubs(:skill_based_round_robin_enabled?).returns(false)
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
      @account.unstub(:skill_based_round_robin_enabled?)
    end

    def test_update_with_closed_at
      @account.stubs(:skill_based_round_robin_enabled?).returns(false)
      t = create_ticket
      t.update_attributes(created_at: Time.now - 10.days, updated_at: Time.now - 10.days)
      closed_at = Time.now - 1.days
      params = {
        status: 5, priority: 2, source: 2, type: "Question",
        closed_at: closed_at
      }
      Account.any_instance.stubs(:shared_ownership_enabled?).returns(false)
      put :update, construct_params({ id: t.display_id, version: 'private' }, params)
      assert_response 200
      t = Helpdesk::Ticket.last
      match_json(update_ticket_pattern(params, t))
      match_json(update_ticket_pattern({}, t))
      assert (t.closed_at - closed_at).to_i == 0
      @account.unstub(:skill_based_round_robin_enabled?)
    end

    def test_ticket_close_after_reopened
      t = create_ticket(status: 5)
      before_reopen_closed_at = t.closed_at
      # Reopening a closed ticket
      put :update, construct_params({ id: t.display_id, version: 'private' }, { status: 2, priority: 2, source: 2 })
      assert_response 200
      t = Helpdesk::Ticket.last
      assert t.status == 2
      # Closing it again
      closed_at = Time.now
      put :update, construct_params({ id: t.display_id, version: 'private' }, { status: 5, priority: 2, source: 2 })
      assert_response 200
      t = Helpdesk::Ticket.last
      after_close_closed_at = t.closed_at
      assert t.status == 5
      assert before_reopen_closed_at != after_close_closed_at
      assert (t.closed_at - closed_at).to_i == 0
    end
  end
end
