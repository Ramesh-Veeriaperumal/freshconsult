require_relative '../test_helper'

class TimeEntriesControllerTest < ActionController::TestCase
  include TimeEntriesTestHelper

  def setup
    super
    Account.any_instance.stubs(:enabled_features_list).returns([:timesheets])
  end

  def teardown
    Account.any_instance.unstub(:enabled_features_list)
  end

  def wrap_cname(params = {})
    { time_entry: params }
  end

  def ticket
    t = Helpdesk::Ticket.joins(:schema_less_ticket).where(deleted: false, spam: false, helpdesk_schema_less_tickets: { boolean_tc02: false }).order('created_at asc').first
    return t if t
    t = create_ticket
    t.update_column(:spam, false)
    t.update_column(:deleted, false)
    t
  end

  def params_hash
    { agent_id: @agent.id }
  end

  def freeze_time(&_block)
    time = Time.zone.now
    Timecop.freeze(time)
    yield
    Timecop.return
  end

  def utc_time(time = Time.zone.now)
    time.utc.as_json
  end

  def sample_time_entry
    time_entry = Helpdesk::TimeSheet.first || create_time_entry
    time_entry
  end

  def time_entry(id)
    Helpdesk::TimeSheet.find_by_id(id)
  end

  def other_agent
    add_agent(@account, name: Faker::Name.name, email: Faker::Internet.email, active: 1, role: 1,
              agent: 1, role_ids: [@account.roles.find_by_name('Agent').id.to_s], ticket_permission: 1)
  end

  def test_destroy
    ts_id = create_time_entry.id
    delete :destroy, controller_params(id: ts_id)
    assert_response 204
    assert Helpdesk::TimeSheet.find_by_id(ts_id).nil?
    assert_equal ' ', @response.body
  end

  def test_destroy_invalid_id
    delete :destroy, controller_params(id: 78_979)
    puts response.body.inspect
    assert_response :missing
  end

  def test_destroy_without_feature
    ts_id = create_time_entry.id
    Account.any_instance.stubs(:enabled_features_list).returns([])
    delete :destroy, controller_params(id: ts_id)
    assert_response 403
    match_json(request_error_pattern(:require_feature, feature: 'Timesheets'))
    Account.any_instance.unstub(:enabled_features_list)
  end

  def test_destroy_without_privilege
    ts_id = create_time_entry(agent_id: other_agent.id).id
    User.any_instance.stubs(:privilege?).with(:edit_time_entries).returns(false)
    delete :destroy, controller_params(id: ts_id)
    User.any_instance.unstub(:privilege?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_destroy_with_ticket_trashed
    ts_id = create_time_entry(agent_id: other_agent.id).id
    Helpdesk::SchemaLessTicket.any_instance.stubs(:trashed).returns(true)
    delete :destroy, controller_params(id: ts_id)
    Helpdesk::SchemaLessTicket.any_instance.unstub(:trashed)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_destroy_with_ticket_spam
    time_sheet = create_time_entry(agent_id: other_agent.id)
    ts_id = time_sheet.id
    Helpdesk::Ticket.find(time_sheet.workable_id).update_attribute(:spam, true)
    delete :destroy, controller_params(id: ts_id)
    assert_response 404
  end

  def test_destroy_with_ticket_deleted
    time_sheet = create_time_entry(agent_id: other_agent.id)
    ts_id = time_sheet.id
    Helpdesk::Ticket.find(time_sheet.workable_id).update_attribute(:deleted, true)
    delete :destroy, controller_params(id: ts_id)
    assert_response 404
  end

  def test_destroy_without_ticket_privilege
    time_sheet = create_time_entry(agent_id: other_agent.id)
    ts_id = time_sheet.id
    User.any_instance.stubs(:has_ticket_permission?).returns(false)
    delete :destroy, controller_params(id: ts_id)
    User.any_instance.unstub(:has_ticket_permission?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_destroy_with_ownership
    ts_id = create_time_entry.id
    User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
    User.any_instance.stubs(:privilege?).with(:edit_time_entries).returns(false).at_most_once
    delete :destroy, controller_params(id: ts_id)
    User.any_instance.unstub(:privilege?)
    assert_response 204
    assert Helpdesk::TimeSheet.find_by_id(ts_id).nil?
    assert_equal ' ', @response.body
  end

  def test_index_without_feature
    Account.any_instance.stubs(:enabled_features_list).returns([])
    get :index, controller_params(billable: 'false')
    match_json(request_error_pattern(:require_feature, feature: 'Timesheets'))
    assert_response 403
    Account.any_instance.unstub(:enabled_features_list)
  end

  def test_index
    agent = add_test_agent(@account)
    user = add_new_user(@account, customer_id: create_company.reload.id)
    get :index, controller_params(billable: 'false', company_id: "#{user.company_id}", agent_id: agent.id, executed_after: 20.days.ago.iso8601, executed_before: 18.days.ago.iso8601)
    assert_response 200
    response = parse_response @response.body
    assert_equal 0, response.size

    t = create_ticket(requester_id: user.id)
    create_time_entry(billable: false, ticket_id: t.id, agent_id: agent.id, executed_at: 19.days.ago.iso8601)
    get :index, controller_params(billable: 'false', company_id: "#{user.company_id}", agent_id: agent.id, executed_after: 20.days.ago.iso8601, executed_before: 18.days.ago.iso8601)
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_eager_loaded_association
    Helpdesk::TimeSheet.update_all(billable: true)
    create_time_entry(billable: false)
    @controller.stubs(:decorate_objects).returns([])
    @controller.stubs(:render).returns(true)
    get :index, controller_params(billable: 'false')
    assert_response 200
    assert controller.instance_variable_get(:@items).all? { |x| x.association(:workable).loaded? }
  ensure
    @controller.unstub(:decorate_objects)
    @controller.unstub(:render)
  end

  def test_index_with_invalid_privileges
    User.any_instance.stubs(:privilege?).with(:view_time_entries).returns(false).at_most_once
    get :index, controller_params(billable: 0)
    User.any_instance.unstub(:privilege?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_index_with_extra_params
    hash = { user_id: 'test', contact_email: 'test' }
    get :index, controller_params(hash)
    assert_response 400
    pattern = []
    hash.keys.each { |key| pattern << bad_request_error_pattern(key, :invalid_field) }
    match_json pattern
  end

  def test_index_with_pagination
    3.times do
      create_time_entry(billable: false)
    end
    get :index, controller_params(billable: 'false', per_page: 1)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    get :index, controller_params(billable: 'false', per_page: 1)
    assert_response 200
    assert JSON.parse(response.body).count == 1
  end

  def test_index_with_pagination_exceeds_limit
    get :index, controller_params(billable: false, per_page: 101)
    assert_response 400
    match_json([bad_request_error_pattern('per_page', :per_page_invalid, max_value: 100)])
  end

  def test_index_with_invalid_params
    get :index, controller_params(company_id: 't', agent_id: 'er', billable: '78', executed_after: '78/34', executed_before: '90/12')
    pattern = [bad_request_error_pattern('billable', :datatype_mismatch, expected_data_type: 'Boolean')]
    pattern << bad_request_error_pattern('agent_id', :datatype_mismatch, expected_data_type: 'Positive Integer')
    pattern << bad_request_error_pattern('company_id', :datatype_mismatch, expected_data_type: 'Positive Integer')
    pattern << bad_request_error_pattern('executed_after', :invalid_date, accepted: :'combined date and time ISO8601')
    pattern << bad_request_error_pattern('executed_before', :invalid_date, accepted: :'combined date and time ISO8601')
    assert_response 400
    match_json pattern
  end

  def test_index_with_invalid_model_params
    get :index, controller_params(company_id: 8989, agent_id: 678_567_567, billable: 'true', executed_after: 23.days.ago.iso8601, executed_before: 2.days.ago.iso8601)
    pattern = [bad_request_error_pattern('agent_id', :absent_in_db, resource: :agent, attribute: :agent_id)]
    pattern << bad_request_error_pattern('company_id', :absent_in_db, resource: :company, attribute: :company_id)
    assert_response 400
    match_json pattern
  end

  def test_index_with_billable
    Helpdesk::TimeSheet.update_all(billable: true)
    get :index, controller_params(billable: 'false')
    assert_response 200
    response = parse_response @response.body
    assert_equal 0, response.size

    create_time_entry(billable: false)
    get :index, controller_params(billable: 'false')
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_executed_after
    get :index, controller_params(executed_after: 6.hours.since.iso8601)
    assert_response 200
    response = parse_response @response.body
    assert_equal 0, response.size

    create_time_entry(executed_at: 9.hours.since.iso8601)
    get :index, controller_params(executed_after: 6.hours.since.iso8601)
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_executed_before
    get :index, controller_params(executed_before: 25.days.ago.iso8601)
    assert_response 200
    response = parse_response @response.body
    assert_equal 0, response.size

    create_time_entry(executed_at: 26.days.ago.iso8601)
    get :index, controller_params(executed_before: 25.days.ago.iso8601)
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_agent_id
    user = add_test_agent(@account)
    get :index, controller_params(agent_id: user.id)
    assert_response 200
    response = parse_response @response.body
    assert_equal 0, response.size

    create_time_entry(agent_id: user.id)
    get :index, controller_params(agent_id: user.id)
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_company_id
    user = add_new_user(@account, customer_id: create_company.reload.id)
    get :index, controller_params(company_id: user.company_id)
    assert_response 200
    response = parse_response @response.body
    assert_equal 0, response.size

    t = create_ticket(requester_id: user.id)
    create_time_entry(ticket_id: t.id)
    get :index, controller_params(company_id: user.company_id)
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_executed_after_and_executed_before
    get :index, controller_params(executed_before: 9.days.ago.iso8601, executed_after: 11.days.ago.iso8601)
    assert_response 200
    response = parse_response @response.body
    assert_equal 0, response.size

    create_time_entry(executed_at: 10.days.ago.iso8601)
    get :index, controller_params(executed_before: 9.days.ago.iso8601, executed_after: 11.days.ago.iso8601)
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_executed_after_and_agent_id
    user = add_test_agent(@account)
    get :index, controller_params(executed_after: 9.days.ago.iso8601, agent_id: user.id)
    assert_response 200
    response = parse_response @response.body
    assert_equal 0, response.size

    create_time_entry(executed_at: 8.days.ago.iso8601, agent_id: user.id)
    get :index, controller_params(executed_after: 9.days.ago.iso8601, agent_id: user.id)
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_executed_after_and_company_id
    user = add_new_user(@account, customer_id: create_company.reload.id)
    get :index, controller_params(executed_after: 9.days.ago.iso8601, company_id: user.company_id)
    assert_response 200
    response = parse_response @response.body
    assert_equal 0, response.size

    t = create_ticket(requester_id: user.id)
    create_time_entry(executed_at: 8.days.ago.iso8601, ticket_id: t.id)
    get :index, controller_params(executed_after: 9.days.ago.iso8601, company_id: user.company_id)
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_agent_id_and_company_id
    agent = add_test_agent(@account)
    user = add_new_user(@account, customer_id: create_company.reload.id)
    get :index, controller_params(agent_id: agent.id, company_id: user.company_id)
    assert_response 200
    response = parse_response @response.body
    assert_equal 0, response.size

    t = create_ticket(requester_id: user.id)
    create_time_entry(agent_id: agent.id, ticket_id: t.id)
    get :index, controller_params(agent_id: agent.id, company_id: user.company_id)
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_company_id_and_billable
    user = add_new_user(@account, customer_id: create_company.reload.id)
    get :index, controller_params(billable: 'false', company_id: user.company_id)
    assert_response 200
    response = parse_response @response.body
    assert_equal 0, response.size

    t = create_ticket(requester_id: user.id)
    create_time_entry(billable: false, ticket_id: t.id)
    get :index, controller_params(billable: 'false', company_id: user.company_id)
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_company_id_and_billable_and_executed_after
    user = add_new_user(@account, customer_id: create_company.reload.id)
    get :index, controller_params(billable: 'false', company_id: user.company_id, executed_after: Time.zone.now.iso8601)
    assert_response 200
    response = parse_response @response.body
    assert_equal 0, response.size

    t = create_ticket(requester_id: user.id)
    create_time_entry(billable: false, ticket_id: t.id, executed_at: 5.hours.since.iso8601)
    get :index, controller_params(billable: 'false', company_id: user.company_id, executed_after: Time.zone.now.iso8601)
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_company_id_and_billable_and_agent_id
    agent = add_test_agent(@account)
    user = add_new_user(@account, customer_id: create_company.reload.id)
    get :index, controller_params(billable: 'false', company_id: user.company_id, agent_id: agent.id)
    assert_response 200
    response = parse_response @response.body
    assert_equal 0, response.size

    t = create_ticket(requester_id: user.id)
    create_time_entry(billable: false, ticket_id: t.id, agent_id: agent.id)
    get :index, controller_params(billable: 'false', company_id: user.company_id, agent_id: agent.id)
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_create_arbitrary_params
    post :create, construct_params({ id: ticket.display_id }, test: 'junk')
    assert_response 400
    match_json [bad_request_error_pattern('test', :invalid_field)]
  end

  def test_create_presence_invalid
    post :create, construct_params(id: 90_909_090)
    assert_response :missing
  end

  def test_create_with_deleted_ticket
    t = ticket
    t.update_column(:deleted, true)
    post :create, construct_params(id: t.id)
    assert_response :missing
    t.update_column(:deleted, false)
  end

  def test_create_with_spam_ticket
    t = ticket
    t.update_column(:spam, true)
    post :create, construct_params(id: t.id)
    assert_response :missing
    t.update_column(:spam, false)
  end

  def test_create_unpermitted_params
    User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
    User.any_instance.stubs(:privilege?).with(:view_time_entries).returns(true)
    User.any_instance.stubs(:privilege?).with(:edit_time_entries).returns(false)
    post :create, construct_params({ id: ticket.display_id }, params_hash.merge(agent_id: 99))
    assert_response 400
    match_json([bad_request_error_pattern('agent_id', :inaccessible_field)])
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_create_start_time_and_timer_not_running
    time = (Time.zone.now - 10.minutes).as_json
    post :create, construct_params({ id: ticket.display_id }, { start_time: time,
                                                                timer_running: false }.merge(params_hash))
    assert_response 400
    match_json [bad_request_error_pattern('start_time',
                                          :timer_running_false, code: :incompatible_field)]
  end

  def test_create_with_no_params
    freeze_time do
      post :create, construct_params({ id: ticket.display_id }, params_hash)
      assert_response 201
      ts = time_entry(parse_response(response.body)['id'])
      match_json time_entry_pattern({ timer_running: true, start_time: utc_time,
                                      executed_at: utc_time, time_spent: '00:00' },
                                    ts)
      match_json time_entry_pattern(ts)
    end
  end

  def test_create_with_start_time_only
    freeze_time do
      start_time = (Time.zone.now - 10.minutes).as_json
      post :create, construct_params({ id: ticket.display_id }, { start_time: start_time }.merge(params_hash))
      assert_response 201
      ts = time_entry(parse_response(response.body)['id'])
      match_json time_entry_pattern(ts)
      match_json time_entry_pattern({ timer_running: true, start_time: utc_time(start_time.to_time),
                                      executed_at: utc_time, time_spent: '00:00' },
                                    ts)
    end
  end

  def test_create_with_start_time_and_time_spent
    start_time = (Time.zone.now - 10.minutes).as_json
    freeze_time do
      post :create, construct_params({ id: ticket.display_id }, { start_time: start_time,
                                                                  time_spent: '03:00' }.merge(params_hash))
      assert_response 201
      ts = time_entry(parse_response(response.body)['id'])
      match_json time_entry_pattern(ts)
      match_json time_entry_pattern({ start_time: utc_time(start_time.to_time), time_spent: '03:00',
                                      timer_running: true, executed_at: utc_time }, ts)
    end
  end

  def test_create_time_spent_only
    freeze_time do
      post :create, construct_params({ id: ticket.display_id }, { time_spent: '03:00' }.merge(params_hash))
      assert_response 201
      ts = time_entry(parse_response(response.body)['id'])
      match_json time_entry_pattern({}, ts)
      match_json time_entry_pattern({ timer_running: false, time_spent: '03:00', start_time: utc_time,
                                      executed_at: utc_time }, ts)
    end
  end

  def test_create_without_time_spent
    freeze_time do
      post :create, construct_params({ id: ticket.display_id }, params_hash)
      assert_response 201
      time_sheet = time_entry(parse_response(response.body)['id'])
      assert time_sheet.time_spent == 0
    end
  end

  def test_create_with_timer_running_and_time_spent
    freeze_time do
      post :create, construct_params({ id: ticket.display_id }, { time_spent: '03:00',
                                                                  timer_running: false }.merge(params_hash))
      assert_response 201
      ts = time_entry(parse_response(response.body)['id'])
      match_json time_entry_pattern(ts)
      match_json time_entry_pattern({ time_spent: '03:00', timer_running: false, start_time: utc_time,
                                      executed_at: utc_time }, ts)
    end
  end

  def test_create_with_other_timer_running
    other_ts = create_time_entry(timer_running: true, user_id: @agent.id)
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
    ts = time_entry(parse_response(response.body)['id'])
    match_json time_entry_pattern(ts)
    refute other_ts.reload.timer_running
  end

  def test_create_with_timer_running_false_when_another_timer_running
    other_ts = create_time_entry(timer_running: true, user_id: @agent.id)
    post :create, construct_params({ id: ticket.display_id }, agent_id: @agent.id, timer_running: false)
    assert_response 201
    ts = time_entry(parse_response(response.body)['id'])
    match_json time_entry_pattern(ts)
    assert other_ts.reload.timer_running
  end

  def test_create_with_all_params
    start_time = (Time.zone.now - 10.minutes).as_json
    executed_at = (Time.zone.now + 20.minutes).as_json
    freeze_time do
      post :create, construct_params({ id: ticket.display_id }, { time_spent: '03:00', start_time: start_time,
                                                                  timer_running: true, executed_at: executed_at,
                                                                  note: 'test note', billable: true, agent_id: @agent.id }.merge(params_hash))
      assert_response 201
      ts = time_entry(parse_response(response.body)['id'])
      match_json time_entry_pattern(ts)
      match_json time_entry_pattern({ time_spent: '03:00', start_time: utc_time(start_time.to_time),
                                      timer_running: false, executed_at: utc_time(executed_at.to_time),
                                      note: 'test note', billable: true }.merge(params_hash), ts)
    end
  end

  def test_create_without_permission_but_ownership
    User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
    User.any_instance.stubs(:privilege?).with(:view_time_entries).returns(true)
    User.any_instance.stubs(:privilege?).with(:edit_time_entries).returns(false)
    post :create, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 201
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_create_with_other_user
    agent = other_agent
    post :create, construct_params({ id: ticket.display_id }, params_hash.merge(agent_id: agent.id))
    assert_response 201
    match_json time_entry_pattern(Helpdesk::TimeSheet.where(user_id: agent.id).first)
  end

  def test_create_with_ticket_trashed
    Helpdesk::SchemaLessTicket.any_instance.stubs(:trashed).returns(true)
    post :create, construct_params({ id: ticket.display_id }, {})
    Helpdesk::SchemaLessTicket.any_instance.unstub(:trashed)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_create_with_ticket_spam
    new_ticket = create_ticket
    new_ticket.update_column(:spam, true)
    post :create, construct_params({ id: new_ticket.display_id }, {})
    assert_response 404
  end

  def test_create_with_ticket_deleted
    new_ticket = create_ticket
    new_ticket.update_column(:deleted, true)
    post :create, construct_params({ id: new_ticket.display_id }, {})
    assert_response 404
  end

  def test_create_without_ticket_privilege
    User.any_instance.stubs(:has_ticket_permission?).returns(false)
    post :create, construct_params({ id: ticket.display_id }, {})
    User.any_instance.unstub(:has_ticket_permission?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_update
    start_time = (Time.zone.now - 10.minutes).iso8601
    executed_at = (Time.zone.now - 20.minutes).iso8601
    ts = create_time_entry(timer_running: false)
    freeze_time do
      put :update, construct_params({ id: ts.id }, time_spent: '03:00', start_time: start_time,
                                                   timer_running: true, executed_at: executed_at,
                                                   note: 'test note', billable: true, agent_id: @agent.id)
      assert_response 200
      match_json time_entry_pattern(ts.reload)
      match_json time_entry_pattern({ time_spent: '03:00', start_time: utc_time(start_time.to_time),
                                      timer_running: false, executed_at: utc_time(executed_at.to_time),
                                      note: 'test note', billable: true }, ts)
    end
  end

  def test_update_numericality_invalid
    start_time = (Time.zone.now - 10.minutes).iso8601
    executed_at = (Time.zone.now - 20.minutes).iso8601
    ts = create_time_entry(timer_running: false)
    put :update, construct_params({ id: ts.id },  time_spent: '03:00', start_time: start_time,
                                                  timer_running: true, executed_at: executed_at,
                                                  note: 'test note', billable: true, agent_id: 'yu')
    assert_response 400
    match_json([bad_request_error_pattern('agent_id', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String)])
  end

  def test_update_presence_invalid
    start_time = (Time.zone.now - 10.minutes).iso8601
    executed_at = (Time.zone.now - 20.minutes).iso8601
    ts = create_time_entry(timer_running: false)
    put :update, construct_params({ id: ts.id },  time_spent: '03:00', start_time: start_time,
                                                  timer_running: true, executed_at: executed_at,
                                                  note: 'test note', billable: true, agent_id: '7878')
    assert_response 400
    match_json([bad_request_error_pattern('agent_id', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String)])
  end

  def test_update_date_time_invalid
    ts = create_time_entry(timer_running: false)
    put :update, construct_params({ id: ts.id },  time_spent: '03:00', start_time: '67/23',
                                                  timer_running: true, executed_at: '89/12',
                                                  note: 'test note', billable: true)
    assert_response 400
    match_json([bad_request_error_pattern('start_time', :invalid_date, accepted: :'combined date and time ISO8601'),
                bad_request_error_pattern('executed_at', :invalid_date, accepted: :'combined date and time ISO8601')])
  end

  def test_update_inclusion_invalid
    start_time = (Time.zone.now - 10.minutes).iso8601
    executed_at = (Time.zone.now - 20.minutes).iso8601
    ts = create_time_entry(timer_running: false)
    put :update, construct_params({ id: ts.id },  time_spent: '03:00', start_time: start_time,
                                                  timer_running: '89', executed_at: executed_at,
                                                  note: 'test note', billable: '12')
    assert_response 400
    match_json([bad_request_error_pattern('timer_running', :datatype_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('billable', :datatype_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String)])
  end

  def test_update_format_invalid
    start_time = (Time.zone.now - 10.minutes).iso8601
    executed_at = (Time.zone.now - 20.minutes).iso8601
    ts = create_time_entry(timer_running: false)
    put :update, construct_params({ id: ts.id },  time_spent: '89:78', start_time: start_time,
                                                  timer_running: true, executed_at: executed_at,
                                                  note: 'test note', billable: true, agent_id: @agent.id)
    assert_response 400
    match_json([bad_request_error_pattern('time_spent', :invalid_format, accepted: 'hh:mm')])
  end

  def test_update_start_time_greater_than_current_time
    start_time = (Time.zone.now + 20.hours).iso8601
    executed_at = (Time.zone.now - 20.minutes).iso8601
    ts = create_time_entry(timer_running: false)
    put :update, construct_params({ id: ts.id },  time_spent: '09:00', start_time: start_time,
                                                  timer_running: true, executed_at: executed_at,
                                                  note: 'test note', billable: true, agent_id: @agent.id)
    assert_response 400
    match_json([bad_request_error_pattern('start_time', :start_time_lt_now)])
  end

  def test_update_timer_running_false_again
    executed_at = (Time.zone.now - 20.minutes).iso8601
    start_time = (Time.zone.now - 20.hours).iso8601
    ts = create_time_entry(timer_running: false)
    put :update, construct_params({ id: ts.id },  time_spent: '09:00', start_time: start_time,
                                                  timer_running: false, executed_at: executed_at,
                                                  note: 'test note', billable: true, agent_id: @agent.id)
    assert_response 400
    match_json([bad_request_error_pattern('timer_running', :timer_running_duplicate),
                bad_request_error_pattern('start_time', :timer_running_false, code: :incompatible_field)])
  end

  def test_update_timer_running_true_again
    executed_at = (Time.zone.now - 20.minutes).iso8601
    start_time = (Time.zone.now - 20.hours).iso8601
    ts = create_time_entry(timer_running: true)
    put :update, construct_params({ id: ts.id },  time_spent: '09:00',
                                                  timer_running: true, executed_at: executed_at, start_time: start_time,
                                                  note: 'test note', billable: true, agent_id: @agent.id)
    assert_response 400
    match_json([bad_request_error_pattern('timer_running', :timer_running_duplicate),
                bad_request_error_pattern('start_time', :timer_running_true, code: :incompatible_field)])
  end

  def test_update_agent_id_when_timer_running
    user = other_agent
    executed_at = (Time.zone.now - 20.minutes).iso8601
    ts = create_time_entry(timer_running: true)
    put :update, construct_params({ id: ts.id },  time_spent: '09:00', executed_at: executed_at,
                                                  note: 'test note', billable: true, agent_id: user.id)
    assert_response 400
    match_json([bad_request_error_pattern('agent_id', :cant_update_user, code: :incompatible_field)])
  end

  def test_update_agent_id_when_timer_not_running
    user = other_agent
    start_time = (Time.zone.now - 10.minutes).iso8601
    executed_at = (Time.zone.now - 20.minutes).iso8601
    ts = create_time_entry(timer_running: false)
    freeze_time do
      put :update, construct_params({ id: ts.id }, time_spent: '01:00', executed_at: executed_at,
                                                   note: 'test note', billable: true, agent_id: user.id)
      assert_response 200
      match_json time_entry_pattern(ts.reload)
      match_json time_entry_pattern({ time_spent: '01:00', agent_id: user.id,
                                      timer_running: false, executed_at: utc_time(executed_at.to_time),
                                      note: 'test note', billable: true }, ts.reload)
    end
  end

  def test_update_agent_id_and_timer_running_true_when_timer_is_not_running
    user = other_agent
    start_time = (Time.zone.now - 10.minutes).iso8601
    executed_at = (Time.zone.now - 20.minutes).iso8601
    ts = create_time_entry(timer_running: false)
    freeze_time do
      put :update, construct_params({ id: ts.id }, time_spent: '01:00', timer_running: true,
                                                   executed_at: executed_at, note: 'test note', billable: true, agent_id: user.id)
      assert_response 200
      match_json time_entry_pattern(ts.reload)
      match_json time_entry_pattern({ time_spent: '01:00', agent_id: user.id,
                                      timer_running: true, executed_at: utc_time(executed_at.to_time),
                                      note: 'test note', billable: true }, ts.reload)
    end
  end

  def test_update_agent_id_for_a_timer_when_another_timer_is_running_with_same_agent
    user = other_agent
    other_ts = create_time_entry(timer_running: true, agent_id: user.id)
    ts = create_time_entry(timer_running: false, user_id: @agent.id)
    put :update, construct_params({ id: ts.id }, agent_id: user.id, timer_running: true)
    assert_response 200
    match_json time_entry_pattern({ timer_running: true, agent_id: user.id }, ts.reload)
    assert_equal other_ts.reload.user_id, ts.user_id
    refute other_ts.timer_running
  end

  def test_update_timer_running_when_another_timer_is_running_with_same_agent
    other_ts = create_time_entry(timer_running: true, agent_id: @agent.id)
    ts = create_time_entry(timer_running: false, user_id: @agent.id)
    put :update, construct_params({ id: ts.id }, timer_running: true)
    assert_response 200
    match_json time_entry_pattern({ timer_running: true, agent_id: @agent.id }, ts.reload)
    assert_equal other_ts.reload.user_id, ts.user_id
    refute other_ts.timer_running
  end

  def test_update_with_timer_running_false_when_another_timer_is_running_with_same_agent
    user = other_agent
    other_ts = create_time_entry(timer_running: true, agent_id: user.id)
    ts = create_time_entry(timer_running: false, user_id: @agent.id)
    put :update, construct_params({ id: ts.id }, agent_id: user.id)
    assert_response 200
    match_json time_entry_pattern({ agent_id: user.id }, ts.reload)
    assert_equal other_ts.reload.user_id, ts.user_id
    assert other_ts.timer_running
  end

  def test_update_agent_id_and_timer_running_false_when_timer_is_running
    user = other_agent
    start_time = (Time.zone.now - 10.minutes).iso8601
    executed_at = (Time.zone.now - 20.minutes).iso8601
    ts = create_time_entry(timer_running: true)
    put :update, construct_params({ id: ts.id }, time_spent: '01:00', timer_running: false,
                                                 executed_at: executed_at, note: 'test note', billable: true, agent_id: user.id)
    assert_response 400
    match_json([bad_request_error_pattern('agent_id', :cant_update_user, code: :incompatible_field)])
  end

  def test_update_timer_running_false_for_all_other_timers_while_creating_time_entry
    t = ticket
    create_time_entry(agent_id: @agent.id, timer_running: true)
    create_time_entry(agent_id: @agent.id, timer_running: true)
    create_time_entry(agent_id: @agent.id, timer_running: true)
    create_time_entry(agent_id: @agent.id, timer_running: true)
    post :create, construct_params({ id: t.display_id }, params_hash)
    assert_response 201
    ts = time_entry(parse_response(response.body)['id'])
    assert ts.timer_running
    assert_equal 1, Account.current.time_sheets.where('user_id= (?) AND timer_running= true', @agent.id).length
  end

  def test_update_with_nullable_fields
    start_time = (Time.zone.now - 10.minutes).iso8601
    executed_at = (Time.zone.now - 20.minutes).iso8601
    ts = create_time_entry(timer_running: true)
    freeze_time do
      put :update, construct_params({ id: ts.id }, time_spent: nil, timer_running: false,
                                                   executed_at: nil, note: 'test note', billable: true)
      assert_response 200
      match_json time_entry_pattern(ts.reload)
      match_json time_entry_pattern({ time_spent: '00:00',
                                      timer_running: false, executed_at: nil,
                                      note: 'test note', billable: true }, ts.reload)
    end
  end

  def test_update_start_time_when_timer_running_already
    start_time = (Time.zone.now - 10.minutes).iso8601
    executed_at = (Time.zone.now - 20.minutes).iso8601
    ts = create_time_entry(timer_running: true)
    put :update, construct_params({ id: ts.id }, time_spent: '09:00', start_time: start_time,
                                                 executed_at: executed_at, note: 'test note', billable: true)
    assert_response 400
    match_json([bad_request_error_pattern('start_time', :timer_running_true, code: :incompatible_field)])
  end

  def test_update_start_time_when_timer_is_not_running
    start_time = (Time.zone.now - 10.minutes).iso8601
    executed_at = (Time.zone.now - 20.minutes).iso8601
    ts = create_time_entry(timer_running: false)
    put :update, construct_params({ id: ts.id }, time_spent: '09:00', start_time: start_time,
                                                 executed_at: executed_at, note: 'test note', billable: true)
    assert_response 400
    match_json([bad_request_error_pattern('start_time', :timer_running_false, code: :incompatible_field)])
  end

  def test_update_start_time_when_timer_running_is_set_to_true
    start_time = (Time.zone.now - 10.minutes).iso8601
    executed_at = (Time.zone.now - 20.minutes).iso8601
    ts = create_time_entry(timer_running: false)
    freeze_time do
      put :update, construct_params({ id: ts.id }, time_spent: '09:42', timer_running: true, start_time: start_time,
                                                   executed_at: executed_at, note: 'test note', billable: true)
      assert_response 200
      match_json time_entry_pattern(ts.reload)
      match_json time_entry_pattern({ time_spent: '09:42', timer_running: true, executed_at: utc_time(executed_at.to_time),
                                      note: 'test note', billable: true, start_time: utc_time(start_time.to_time) }, ts.reload)
    end
  end

  def test_update_start_time_when_timer_running_is_set_to_false
    start_time = (Time.zone.now - 10.minutes).iso8601
    executed_at = (Time.zone.now - 20.minutes).iso8601
    ts = create_time_entry(timer_running: true)
    put :update, construct_params({ id: ts.id }, time_spent: '09:00', start_time: start_time, timer_running: false,
                                                 executed_at: executed_at, note: 'test note', billable: true)
    assert_response 400
    match_json([bad_request_error_pattern('start_time', :timer_running_true, code: :incompatible_field)])
  end

  def test_update_with_timer_running_true_valid
    executed_at = (Time.zone.now - 20.minutes).iso8601
    ts = create_time_entry(timer_running: false)
    freeze_time do
      put :update, construct_params({ id: ts.id }, timer_running: true,
                                                   executed_at: executed_at, note: 'test note', billable: true)
      assert_response 200
      match_json time_entry_pattern(ts.reload)
      match_json time_entry_pattern({ timer_running: true, executed_at: utc_time(executed_at.to_time),
                                      note: 'test note', billable: true, start_time: utc_time }, ts.reload)
    end
  end

  def test_update_with_timer_running_false_valid
    executed_at = (Time.zone.now - 20.minutes).iso8601
    ts = create_time_entry(timer_running: true)
    freeze_time do
      time_spent = (Time.zone.now - ts.start_time).abs.round
      if time_spent.is_a? Numeric
        hours, minutes = time_spent.divmod(60).first.divmod(60)
        time_spent = format('%02d:%02d', hours, minutes)
      end
      put :update, construct_params({ id: ts.id }, timer_running: false,
                                                   executed_at: executed_at, note: 'test note', billable: true)
      assert_response 200
      match_json time_entry_pattern(ts.reload)
      match_json time_entry_pattern({ time_spent: time_spent, timer_running: false, executed_at: utc_time(executed_at.to_time),
                                      note: 'test note', billable: true }, ts.reload)
    end
  end

  def test_update_with_time_spent
    executed_at = (Time.zone.now - 20.minutes).iso8601
    ts = create_time_entry(timer_running: false)
    freeze_time do
      put :update, construct_params({ id: ts.id }, time_spent: '09:42', timer_running: true,
                                                   executed_at: executed_at, note: 'test note', billable: true)
      assert_response 200
      match_json time_entry_pattern(ts.reload)
      match_json time_entry_pattern({ time_spent: '09:42', timer_running: true, executed_at: utc_time(executed_at.to_time),
                                      note: 'test note', billable: true, start_time: utc_time }, ts.reload)
    end
  end

  def test_update_with_timer_running_false_and_time_spent
    executed_at = (Time.zone.now - 20.minutes).iso8601
    ts = create_time_entry(timer_running: true)
    freeze_time do
      put :update, construct_params({ id: ts.id }, time_spent: '09:42', timer_running: false,
                                                   executed_at: executed_at, note: 'test note', billable: true)
      assert_response 200
      match_json time_entry_pattern(ts.reload)
      match_json time_entry_pattern({ time_spent: '09:42', timer_running: false, executed_at: utc_time(executed_at.to_time),
                                      note: 'test note', billable: true }, ts.reload)
    end
  end

  def test_update_without_privilege
    ts = create_time_entry(timer_running: true, agent_id: other_agent.id)
    User.any_instance.stubs(:privilege?).with(:edit_time_entries).returns(false).at_most_once
    put :update, construct_params({ id: ts.id }, time_spent: '09:00', note: 'test note', billable: true)
    User.any_instance.unstub(:privilege?)
    controller.class.any_instance.unstub(:privilege?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_update_without_feature
    ts = create_time_entry(timer_running: true)
    Account.any_instance.stubs(:enabled_features_list).returns([])
    put :update, construct_params({ id: ts.id }, time_spent: '09:00', note: 'test note', billable: true)
    match_json(request_error_pattern(:require_feature, feature: 'Timesheets'))
    assert_response 403
    Account.any_instance.unstub(:enabled_features_list)
  end

  def test_update_with_ticket_trashed
    Helpdesk::SchemaLessTicket.any_instance.stubs(:trashed).returns(true)
    put :update, construct_params({ id: sample_time_entry.id }, note: 'test note', billable: true)
    Helpdesk::SchemaLessTicket.any_instance.unstub(:trashed)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_update_with_ticket_spam
    new_ticket = sample_time_entry.workable
    new_ticket.update_column(:spam, true)
    put :update, construct_params({ id: sample_time_entry.id }, note: 'test note', billable: true)
    new_ticket.update_column(:spam, false)
    assert_response 404
  end

  def test_update_with_ticket_deleted
    new_ticket = sample_time_entry.workable
    new_ticket.update_column(:deleted, true)
    put :update, construct_params({ id: sample_time_entry.id }, note: 'test note', billable: true)
    new_ticket.update_column(:deleted, false)
    assert_response 404
  end

  def test_update_without_ticket_privilege
    User.any_instance.stubs(:has_ticket_permission?).returns(false)
    put :update, construct_params({ id: sample_time_entry.id }, note: 'test note', billable: true)
    User.any_instance.unstub(:has_ticket_permission?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def toggle_with_invalid_id
    put :toggle_timer, construct_params({ id: 99 }, test: 'junk')
    assert_response :missing
  end

  def test_toggle_with_params
    put :toggle_timer, construct_params({ id: Helpdesk::TimeSheet.first }, test: 'junk')
    assert_response 400
    match_json(request_error_pattern(:no_content_required))
  end

  def test_toggle_off_timer
    timer = Helpdesk::TimeSheet.where(timer_running: true).first
    freeze_time do
      time = Time.zone.now - 1.hour - 23.minutes
      timer.update_column(:start_time, time)
      put :toggle_timer, construct_params({ id: timer.id }, {})
      puts response.body.inspect
      assert_response 200
      match_json(time_entry_pattern({ timer_running: false, time_spent: '01:23' }, timer.reload))
    end
  end

  def test_toggle_on_timer_with_other_timer_on
    timer_on = @account.time_sheets.where(timer_running: true).first
    timer_off = @account.time_sheets.where(timer_running: false).first
    Helpdesk::TimeSheet.update_all("user_id = #{@agent.id}", id: [timer_on.id, timer_off.id])
    put :toggle_timer, construct_params({ id: timer_off.id }, {})
    assert_response 200
    refute timer_on.reload.timer_running
    assert timer_off.reload.timer_running
  end

  def test_toggle_invalid_record
    ts = Helpdesk::TimeSheet.first
    Helpdesk::TimeSheet.any_instance.stubs(:update_attributes).returns(false)
    Helpdesk::TimeSheet.any_instance.stubs(:errors).returns([[:user_id, :"can't be blank"]])
    put :toggle_timer, construct_params({ id: ts.id }, {})
    Helpdesk::TimeSheet.any_instance.unstub(:update_attributes, :errors)
    assert_response 400
    match_json([bad_request_error_pattern('user_id', :absent_in_db, attribute: :user_id, resource: :contact)])
  end

  def test_toggle_timer_with_ticket_trashed
    Helpdesk::SchemaLessTicket.any_instance.stubs(:trashed).returns(true)
    put :toggle_timer, construct_params({ id: sample_time_entry.id }, {})
    Helpdesk::SchemaLessTicket.any_instance.unstub(:trashed)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_toggle_timer_with_ticket_spam
    new_ticket = sample_time_entry.workable
    new_ticket.update_column(:spam, true)
    put :toggle_timer, construct_params({ id: sample_time_entry.id }, {})
    new_ticket.update_column(:spam, false)
    assert_response 404
  end

  def test_toggle_timer_with_ticket_deleted
    new_ticket = sample_time_entry.workable
    new_ticket.update_column(:deleted, true)
    put :toggle_timer, construct_params({ id: sample_time_entry.id }, {})
    new_ticket.update_column(:deleted, false)
    assert_response 404
  end

  def test_toggle_timer_without_ticket_privilege
    User.any_instance.stubs(:has_ticket_permission?).returns(false)
    put :toggle_timer, construct_params({ id: sample_time_entry.id }, {})
    User.any_instance.unstub(:has_ticket_permission?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_ticket_time_entries
    t = ticket
    create_time_entry(ticket_id: t.id)
    get :ticket_time_entries, controller_params(id: t.id)
    assert_response 200
    result_pattern = []
    t.time_sheets.each do |n|
      result_pattern << time_entry_pattern(n)
    end
    match_json(result_pattern)
  end

  def test_ticket_time_entries_with_ticket_deleted
    t = ticket
    t.update_column(:deleted, true)
    get :ticket_time_entries, controller_params(id: t.display_id)
    assert_response :missing
    ticket.update_column(:deleted, false)
  end

  def test_ticket_time_entries_with_ticket_spam
    t = ticket
    t.update_column(:spam, true)
    get :ticket_time_entries, controller_params(id: t.display_id)
    assert_response :missing
    ticket.update_column(:spam, false)
  end

  def test_ticket_time_entries_without_privilege
    t = ticket
    User.any_instance.stubs(:privilege?).with(:view_time_entries).returns(false).at_most_once
    get :ticket_time_entries, controller_params(id: t.display_id)
    User.any_instance.unstub(:privilege?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_ticket_time_entries_invalid_id
    get :ticket_time_entries, controller_params(id: 56_756_767)
    assert_response :missing
    assert_equal ' ', @response.body
  end

  def test_ticket_time_entries_with_pagination
    t = ticket
    3.times do
      create_time_entry(ticket_id: t.id)
    end
    get :ticket_time_entries, controller_params(id: t.display_id, per_page: 1)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    get :ticket_time_entries, controller_params(id: t.display_id, per_page: 1, page: 2)
    assert_response 200
    assert JSON.parse(response.body).count == 1
  end

  def test_ticket_time_entries_with_pagination_exceeds_limit
    get :ticket_time_entries, controller_params(id: ticket.display_id, per_page: 101)
    assert_response 400
    match_json([bad_request_error_pattern('per_page', :per_page_invalid, max_value: 100)])
  end

  def test_ticket_time_entries_with_ticket_trashed
    Helpdesk::SchemaLessTicket.any_instance.stubs(:trashed).returns(true)
    get :ticket_time_entries, controller_params(id: ticket.display_id)
    Helpdesk::SchemaLessTicket.any_instance.unstub(:trashed)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_ticket_time_entries_without_ticket_privilege
    time_sheet = create_time_entry(agent_id: other_agent.id)
    ts_id = time_sheet.id
    User.any_instance.stubs(:has_ticket_permission?).returns(false)
    get :ticket_time_entries, controller_params(id: time_sheet.workable.display_id)
    User.any_instance.unstub(:has_ticket_permission?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_ticket_time_entries_with_link_header
    t = ticket
    3.times do
      create_time_entry(ticket_id: t.id)
    end
    per_page = Helpdesk::TimeSheet.where(workable_id: t.id).count - 1
    get :ticket_time_entries, controller_params(id: t.display_id, per_page: per_page)
    assert_response 200
    assert JSON.parse(response.body).count == per_page
    assert_equal "<http://#{@request.host}/api/v2/tickets/#{t.display_id}/time_entries?per_page=#{per_page}&page=2>; rel=\"next\"", response.headers['Link']

    get :ticket_time_entries, controller_params(id: t.display_id, per_page: per_page, page: 2)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    assert_nil response.headers['Link']
  end

  def test_index_with_link_header
    3.times do
      create_time_entry
    end
    total_time_entries = @account.time_sheets.where(helpdesk_tickets: { spam: 0, deleted: 0 })
    per_page = total_time_entries.count - 1
    get :index, controller_params(per_page: per_page)
    assert_response 200
    assert JSON.parse(response.body).count == per_page
    result_pattern = []
    total_time_entries.take(per_page).each do |n|
      result_pattern << time_entry_pattern(n)
    end
    match_json(result_pattern.ordered!)
    assert_equal "<http://#{@request.host}/api/v2/time_entries?per_page=#{per_page}&page=2>; rel=\"next\"", response.headers['Link']

    get :index, controller_params(per_page: per_page, page: 2)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    assert_nil response.headers['Link']
  end

  def test_index_with_agent_has_assigned_ticket_permission
    Agent.any_instance.stubs(:ticket_permission).returns(3)
    user = add_new_user(@account)
    Helpdesk::Ticket.update_all(responder_id: nil)
    Helpdesk::TimeSheet.first.workable.update_column(:responder_id, @agent.id)
    expected = @account.time_sheets.where(helpdesk_tickets: { spam: 0, deleted: 0, responder_id: @agent.id }).count
    get :index, controller_params({})
    assert_response 200
    assert_equal expected, JSON.parse(response.body).count
  ensure
    Agent.any_instance.unstub(:ticket_permission)
  end

  def test_index_with_internal_agent_has_assigned_ticket_permission
    Agent.any_instance.stubs(:ticket_permission).returns(3)
    user = add_new_user(@account)
    Helpdesk::Ticket.update_all(responder_id: nil)
    workable = Helpdesk::TimeSheet.first.workable
    workable.internal_agent_id = @agent.id
    workable.save
    expected = @account.time_sheets.where(:workable_id => @account.tickets.where(:internal_agent_id => @agent.id).pluck(:id)).count
    Account.any_instance.stubs(:shared_ownership_enabled?).returns(true)
    Account.any_instance.stubs(:features?).with(:timesheets).returns(true)
    get :index, controller_params({})
    puts response.body.inspect
    assert_response 200
    assert_equal expected, JSON.parse(response.body).count
  ensure
    Agent.any_instance.unstub(:ticket_permission)
    Account.any_instance.unstub(:features)
  end

  def test_index_with_agent_has_group_ticket_permission_and_ticket_requested
    Agent.any_instance.stubs(:ticket_permission).returns(2)
    Helpdesk::Ticket.update_all(responder_id: nil, group_id: nil)
    expected = @account.time_sheets.where(helpdesk_tickets: { spam: 0, deleted: 0, requester_id: @agent.id }).count
    get :index, controller_params({})
    assert_response 200
    assert_equal expected, JSON.parse(response.body).count
  ensure
    Agent.any_instance.unstub(:ticket_permission)
  end

  def test_index_with_agent_has_group_ticket_permission_and_ticket_responded
    Agent.any_instance.stubs(:ticket_permission).returns(2)
    Helpdesk::Ticket.update_all(responder_id: nil, group_id: nil)
    Helpdesk::TimeSheet.first.workable.update_column(:responder_id, @agent.id)
    expected = @account.time_sheets.where(helpdesk_tickets: { spam: 0, deleted: 0, responder_id: @agent.id }).count
    get :index, controller_params({})
    assert_response 200
    assert_equal expected, JSON.parse(response.body).count
  ensure
    Agent.any_instance.unstub(:ticket_permission)
  end

  def test_index_with_agent_has_group_ticket_permission
    Agent.any_instance.stubs(:ticket_permission).returns(2)
    group_id = create_group_with_agents(@account, agent_list: [@agent.id])
    user = add_new_user(@account)
    Helpdesk::Ticket.update_all(responder_id: nil, group_id: nil, requester_id: user.id)
    Helpdesk::TimeSheet.first.workable.update_column(:group_id, group_id)
    expected = @account.time_sheets.where(helpdesk_tickets: { spam: 0, deleted: 0, group_id: group_id }).count
    get :index, controller_params({})
    assert_response 200
    assert_equal expected, JSON.parse(response.body).count
  ensure
    Agent.any_instance.unstub(:ticket_permission)
    Group.find(group_id).destroy
  end

  def test_index_with_internal_agent_has_group_ticket_permission
    Agent.any_instance.stubs(:ticket_permission).returns(2)
    group = create_group_with_agents(@account, agent_list: [@agent.id])
    user = add_new_user(@account)
    Helpdesk::Ticket.update_all(responder_id: nil, group_id: nil, requester_id: user.id)
    workable = Helpdesk::TimeSheet.first.workable
    workable.internal_group_id = group.id
    workable.save
    expected = @account.time_sheets.where(:workable_id => @account.tickets.where(:internal_group_id => group.id).pluck(:id)).count
    Account.any_instance.stubs(:shared_ownership_enabled?).returns(true)
    Account.any_instance.stubs(:features?).with(:timesheets).returns(true)
    get :index, controller_params({})
    assert_response 200
    assert_equal expected, JSON.parse(response.body).count
  ensure
    Agent.any_instance.unstub(:ticket_permission)
    Group.find(group.id).destroy
    Account.any_instance.unstub(:features)
  end

  def test_index_with_agent_has_all_ticket_permission
    Agent.any_instance.stubs(:ticket_permission).returns(1)
    expected = @account.time_sheets.where(helpdesk_tickets: { spam: 0, deleted: 0 }).count
    get :index, controller_params({})
    assert_response 200
    assert_equal expected, JSON.parse(response.body).count
  ensure
    Agent.any_instance.unstub(:ticket_permission)
  end

  def test_update_running_timer_with_start_time_nil
    te = sample_time_entry
    te.update_column(:start_time, Time.zone.now)
    te.update_column(:executed_at, Time.zone.now)
    time_spent = te.reload.time_spent
    assert_not_nil time_spent
    start_time = te.start_time
    executed_at = te.executed_at
    put :update, construct_params({ id: te.id }, start_time: nil, executed_at: nil)
    assert_response 200
    assert_equal time_spent, te.reload.time_spent
    assert_equal start_time, te.start_time
    assert_equal executed_at, te.executed_at
  end

  def test_update_time_spent_present_timer_with_timer_running_true
    te = sample_time_entry
    put :update, construct_params({ id: te.id }, time_spent: '05:00')
    assert_equal 18_000, te.reload.time_spent
    assert_response 200
    put :update, construct_params({ id: te.id }, timer_running: true)
    assert_equal 18_000, te.reload.time_spent
    assert_response 200
  end

  def test_toggle_timer_when_start_time_is_nil
    te = sample_time_entry
    te.update_column(:start_time, nil)
    put :toggle_timer, construct_params({ id: te.id }, {})
    assert_response 200
    assert_not_nil te.time_spent
  end

  def test_create_with_start_time_and_time_spent_array
    start_time = (Time.zone.now - 10.minutes).as_json
    freeze_time do
      post :create, construct_params({ id: ticket.display_id }, { start_time: start_time,
                                                                  time_spent: ['03:00'] }.merge(params_hash))
      assert_response 400
      match_json([bad_request_error_pattern('time_spent', :datatype_mismatch, expected_data_type: 'Integer', prepend_msg: :input_received, given_data_type: Array)])
    end
  end

  def test_update_time_entry_with_other_agent_id_and_no_access
    te = create_time_entry(timer_running: false)
    User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
    User.any_instance.stubs(:privilege?).with(:view_time_entries).returns(true)
    User.any_instance.stubs(:privilege?).with(:edit_time_entries).returns(false)
    put :update, construct_params({ id: te.id }, agent_id: other_agent.id)
    assert_response 400
    match_json([bad_request_error_pattern('agent_id', :inaccessible_field)])
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_update_time_entry_with_and_no_access
    ts = sample_time_entry
    User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(true)
    User.any_instance.stubs(:privilege?).with(:view_time_entries).returns(true)
    User.any_instance.stubs(:privilege?).with(:edit_time_entries).returns(false)
    put :update, construct_params({ id: ts.id }, billable: true)
    assert_response 200
    match_json time_entry_pattern(ts.reload)
    match_json time_entry_pattern({ billable: true }, ts.reload)
  ensure
    User.any_instance.unstub(:privilege?)
  end
end
