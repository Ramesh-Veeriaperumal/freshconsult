require_relative '../test_helper'

class TimeSheetsControllerTest < ActionController::TestCase
  def controller_params(params = {})
    remove_wrap_params
    request_params.merge(params)
  end

  def wrap_cname(params = {})
    { time_sheet: params }
  end

  def ticket
    Helpdesk::Ticket.first
  end

  def params_hash
    { ticket_id: ticket.display_id, user_id: @agent.id }
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

  def time_sheet(id)
    Helpdesk::TimeSheet.find_by_id(id)
  end

  def other_agent
    Agent.where('user_id != ?', @agent.id).first.try(:user) || add_agent(@account,
                                                                         name: Faker::Name.name, email: Faker::Internet.email, active: 1, role: 1,
                                                                         agent: 1, role_ids: [@account.roles.find_by_name('Agent').id.to_s], ticket_permission: 1)
  end

  def test_destroy
    ts_id = create_time_sheet.id
    delete :destroy, controller_params(id: ts_id)
    assert_response :no_content
    assert Helpdesk::TimeSheet.find_by_id(ts_id).nil?
    assert_equal ' ', @response.body
  end

  def test_destroy_invalid_id
    delete :destroy, controller_params(id: 78_979)
    assert_response :not_found
  end

  def test_destroy_without_feature
    ts_id = create_time_sheet.id
    controller.class.any_instance.stubs(:feature?).returns(false).once
    delete :destroy, controller_params(id: ts_id)
    match_json(request_error_pattern('require_feature', feature: 'Timesheets'))
    assert_response :forbidden
  end

  def test_destroy_without_privilege
    ts_id = create_time_sheet.id
    User.any_instance.stubs(:privilege?).with(:edit_time_entries).returns(false).at_most_once
    delete :destroy, controller_params(id: ts_id)
    assert_response :forbidden
    match_json(request_error_pattern('access_denied'))
  end

  def test_index_without_feature
    controller.class.any_instance.stubs(:feature?).returns(false).once
    get :index, controller_params(billable: 0)
    match_json(request_error_pattern('require_feature', feature: 'Timesheets'))
    assert_response :forbidden
  end

  def test_index
    agent = add_test_agent(@account)
    group = create_group_with_agents(@account, agent_list: [agent.id])
    user = add_new_user(@account, customer_id: create_company.reload.id)
    get :index, controller_params(billable: 0, company_id: user.customer_id, user_id: agent.id, executed_after: 20.days.ago.to_s, executed_before: 18.days.ago.to_s)
    assert_response :success
    response = parse_response @response.body
    assert_equal 0, response.size

    t = create_ticket(requester_id: user.id)
    create_time_sheet(billable: 0, ticket_id: t.id, user_id: agent.id, executed_at: 19.days.ago.to_s)
    get :index, controller_params(billable: 0, company_id: user.customer_id, user_id: agent.id, group_id: group.id, executed_after: 20.days.ago.to_s, executed_before: 18.days.ago.to_s)
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_eager_loaded_association
    Helpdesk::TimeSheet.update_all(billable: 1)
    create_time_sheet(billable: 0)
    get :index, controller_params(billable: 0)
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
    assert controller.instance_variable_get(:@time_sheets).all? { |x| x.association(:workable).loaded? }
  end

  def test_index_with_invalid_privileges
    User.any_instance.stubs(:privilege?).with(:view_time_entries).returns(false).at_most_once
    get :index, controller_params(billable: 0)
    assert_response :forbidden
    match_json(request_error_pattern('access_denied'))
  end

  def test_index_with_extra_params
    hash = { agent_id: 'test', contact_email: 'test' }
    get :index, controller_params(hash)
    assert_response :bad_request
    pattern = []
    hash.keys.each { |key| pattern << bad_request_error_pattern(key, 'invalid_field') }
    match_json pattern
  end

  def test_index_with_pagination
    3.times do
      create_time_sheet(billable: 0)
    end
    get :index, controller_params(billable: 0, per_page: 1)
    assert_response :success
    assert JSON.parse(response.body).count == 1
    get :index, controller_params(billable: 0, per_page: 1)
    assert_response :success
    assert JSON.parse(response.body).count == 1
  end

  def test_time_sheets_with_pagination_exceeds_limit
    ApiConstants::DEFAULT_PAGINATE_OPTIONS.stubs(:[]).with(:per_page).returns(3)
    ApiConstants::DEFAULT_PAGINATE_OPTIONS.stubs(:[]).with(:page).returns(1)
    4.times do
      create_time_sheet(billable: 0)
    end
    get :index, controller_params(billable: 0, per_page: 4)
    assert_response :success
    assert JSON.parse(response.body).count == 3
    ApiConstants::DEFAULT_PAGINATE_OPTIONS.unstub(:[])
  end

  def test_index_with_invalid_params
    get :index, controller_params(company_id: 't', user_id: 'er', billable: '78', executed_after: '78/34', executed_before: '90/12')
    pattern = [bad_request_error_pattern('billable', 'Should be a value in the list 0,false,1,true')]
    pattern << bad_request_error_pattern('user_id', "can't be blank")
    pattern << bad_request_error_pattern('company_id', "can't be blank")
    pattern << bad_request_error_pattern('executed_after', 'is not a date')
    pattern << bad_request_error_pattern('executed_before', 'is not a date')
    assert_response :bad_request
    match_json pattern
  end

  def test_index_with_billable
    Helpdesk::TimeSheet.update_all(billable: 1)
    get :index, controller_params(billable: 0)
    assert_response :success
    response = parse_response @response.body
    assert_equal 0, response.size

    create_time_sheet(billable: 0)
    get :index, controller_params(billable: 0)
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_group_id
    user = add_test_agent(@account)
    group = create_group_with_agents(@account, agent_list: [user.id])
    get :index, controller_params(group_id: group.id)
    assert_response :success
    response = parse_response @response.body
    assert_equal 0, response.size

    create_time_sheet(user_id: user.id)
    get :index, controller_params(group_id: group.id)
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_executed_after
    get :index, controller_params(executed_after: 6.hours.since.to_s)
    assert_response :success
    response = parse_response @response.body
    assert_equal 0, response.size

    create_time_sheet(executed_at: 9.hours.since.to_s)
    get :index, controller_params(executed_after: 6.hours.since.to_s)
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_executed_before
    get :index, controller_params(executed_before: 25.days.ago.to_s)
    assert_response :success
    response = parse_response @response.body
    assert_equal 0, response.size

    create_time_sheet(executed_at: 26.days.ago.to_s)
    get :index, controller_params(executed_before: 25.days.ago.to_s)
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_user_id
    user = add_test_agent(@account)
    get :index, controller_params(user_id: user.id)
    assert_response :success
    response = parse_response @response.body
    assert_equal 0, response.size

    create_time_sheet(user_id: user.id)
    get :index, controller_params(user_id: user.id)
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_company_id
    user = add_new_user(@account, customer_id: create_company.reload.id)
    get :index, controller_params(company_id: user.customer_id)
    assert_response :success
    response = parse_response @response.body
    assert_equal 0, response.size

    t = create_ticket(requester_id: user.id)
    create_time_sheet(ticket_id: t.id)
    get :index, controller_params(company_id: user.customer_id)
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_executed_after_and_executed_before
    get :index, controller_params(executed_before: 9.days.ago.to_s, executed_after: 11.days.ago.to_s)
    assert_response :success
    response = parse_response @response.body
    assert_equal 0, response.size

    create_time_sheet(executed_at: 10.days.ago.to_s)
    get :index, controller_params(executed_before: 9.days.ago.to_s, executed_after: 11.days.ago.to_s)
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_executed_after_and_user_id
    user = add_test_agent(@account)
    get :index, controller_params(executed_after: 9.days.ago.to_s, user_id: user.id)
    assert_response :success
    response = parse_response @response.body
    assert_equal 0, response.size

    create_time_sheet(executed_at: 8.days.ago.to_s, user_id: user.id)
    get :index, controller_params(executed_after: 9.days.ago.to_s, user_id: user.id)
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_executed_after_and_company_id
    user = add_new_user(@account, customer_id: create_company.reload.id)
    get :index, controller_params(executed_after: 9.days.ago.to_s, company_id: user.customer_id)
    assert_response :success
    response = parse_response @response.body
    assert_equal 0, response.size

    t = create_ticket(requester_id: user.id)
    create_time_sheet(executed_at: 8.days.ago.to_s, ticket_id: t.id)
    get :index, controller_params(executed_after: 9.days.ago.to_s, company_id: user.customer_id)
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_user_id_and_company_id
    agent = add_test_agent(@account)
    user = add_new_user(@account, customer_id: create_company.reload.id)
    get :index, controller_params(user_id: agent.id, company_id: user.customer_id)
    assert_response :success
    response = parse_response @response.body
    assert_equal 0, response.size

    t = create_ticket(requester_id: user.id)
    create_time_sheet(user_id: agent.id, ticket_id: t.id)
    get :index, controller_params(user_id: agent.id, company_id: user.customer_id)
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_company_id_and_billable
    user = add_new_user(@account, customer_id: create_company.reload.id)
    get :index, controller_params(billable: 0, company_id: user.customer_id)
    assert_response :success
    response = parse_response @response.body
    assert_equal 0, response.size

    t = create_ticket(requester_id: user.id)
    create_time_sheet(billable: 0, ticket_id: t.id)
    get :index, controller_params(billable: 0, company_id: user.customer_id)
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_company_id_and_billable_and_executed_after
    user = add_new_user(@account, customer_id: create_company.reload.id)
    get :index, controller_params(billable: 0, company_id: user.customer_id, executed_after: Time.zone.now.to_s)
    assert_response :success
    response = parse_response @response.body
    assert_equal 0, response.size

    t = create_ticket(requester_id: user.id)
    create_time_sheet(billable: 0, ticket_id: t.id, executed_at: 5.hours.since.to_s)
    get :index, controller_params(billable: 0, company_id: user.customer_id, executed_after: Time.zone.now.to_s)
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_company_id_and_billable_and_user_id
    agent = add_test_agent(@account)
    user = add_new_user(@account, customer_id: create_company.reload.id)
    get :index, controller_params(billable: 0, company_id: user.customer_id, user_id: agent.id)
    assert_response :success
    response = parse_response @response.body
    assert_equal 0, response.size

    t = create_ticket(requester_id: user.id)
    create_time_sheet(billable: 0, ticket_id: t.id, user_id: agent.id)
    get :index, controller_params(billable: 0, company_id: user.customer_id, user_id: agent.id)
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_create_arbitrary_params
    post :create, construct_params({}, test: 'junk')
    assert_response :bad_request
    match_json [bad_request_error_pattern('test', 'invalid_field')]
  end

  def test_create_unpermitted_params
    @controller.stubs(:privilege?).with(:edit_time_entries).returns(false)
    @controller.stubs(:privilege?).with(:all).returns(true)
    post :create, construct_params({}, params_hash.merge(user_id: 99))
    assert_response :bad_request
    match_json([bad_request_error_pattern('user_id', 'invalid_field')])
    @controller.unstub(:privilege?)
  end

  def test_create_start_time_and_timer_not_running
    post :create, construct_params({}, { start_time: (Time.zone.now - 10.minutes).as_json,
                                         timer_running: false }.merge(params_hash))
    assert_response :bad_request
    match_json [bad_request_error_pattern('start_time',
                                          'Should be blank if timer_running is false')]
  end

  def test_create_with_no_params
    freeze_time do
      post :create, construct_params({}, params_hash)
      assert_response :created
      ts = time_sheet(parse_response(response.body)['id'])
      match_json time_sheet_pattern({ timer_running: true, start_time: utc_time,
                                      executed_at: utc_time, time_spent: '00:00' },
                                    ts)
      match_json time_sheet_pattern(ts)
    end
  end

  def test_create_with_start_time_only
    freeze_time do
      start_time = (Time.zone.now - 10.minutes).as_json
      post :create, construct_params({}, { start_time: start_time }.merge(params_hash))
      assert_response :created
      ts = time_sheet(parse_response(response.body)['id'])
      match_json time_sheet_pattern(ts)
      match_json time_sheet_pattern({ timer_running: true, start_time: utc_time(start_time.to_time),
                                      executed_at: utc_time, time_spent: '00:00' },
                                    ts)
    end
  end

  def test_create_with_start_time_and_time_spent
    start_time = (Time.zone.now - 10.minutes).as_json
    freeze_time do
      post :create, construct_params({}, { start_time: start_time,
                                           time_spent: '03:00' }.merge(params_hash))
      assert_response :created
      ts = time_sheet(parse_response(response.body)['id'])
      match_json time_sheet_pattern(ts)
      match_json time_sheet_pattern({ start_time: utc_time(start_time.to_time), time_spent: '03:00',
                                      timer_running: true, executed_at: utc_time }, ts)
    end
  end

  def test_create_time_spent_only
    freeze_time do
      post :create, construct_params({}, { time_spent: '03:00' }.merge(params_hash))
      assert_response :created
      ts = time_sheet(parse_response(response.body)['id'])
      match_json time_sheet_pattern({}, ts)
      match_json time_sheet_pattern({ timer_running: false, time_spent: '03:00', start_time: utc_time,
                                      executed_at: utc_time }, ts)
    end
  end

  def test_create_with_timer_running_and_time_spent
    freeze_time do
      post :create, construct_params({}, { time_spent: '03:00',
                                           timer_running: false }.merge(params_hash))
      assert_response :created
      ts = time_sheet(parse_response(response.body)['id'])
      match_json time_sheet_pattern(ts)
      match_json time_sheet_pattern({ time_spent: '03:00', timer_running: false, start_time: utc_time,
                                      executed_at: utc_time }, ts)
    end
  end

  def test_create_with_other_timer_running
    other_ts = Helpdesk::TimeSheet.find_by_user_id_and_timer_running(@agent.id, true)
    post :create, construct_params({}, params_hash)
    assert_response :created
    ts = time_sheet(parse_response(response.body)['id'])
    match_json time_sheet_pattern(ts)
    refute = other_ts.timer_running
  end

  def test_create_with_all_params
    start_time = (Time.zone.now - 10.minutes).as_json
    executed_at = (Time.zone.now + 20.minutes).as_json
    freeze_time do
      post :create, construct_params({}, { time_spent: '03:00', start_time: start_time,
                                           timer_running: true, executed_at: executed_at,
                                           note: 'test note', billable: true, user_id: @agent.id }.merge(params_hash))
      assert_response :created
      ts = time_sheet(parse_response(response.body)['id'])
      match_json time_sheet_pattern(ts)
      match_json time_sheet_pattern({ time_spent: '03:00', start_time: utc_time(start_time.to_time),
                                      timer_running: false, executed_at: utc_time(executed_at.to_time),
                                      note: 'test note', billable: true }.merge(params_hash), ts)
    end
  end

  def test_create_without_permission_but_ownership
    @controller.stubs(:privilege?).with(:edit_time_entries).returns(false)
    @controller.stubs(:privilege?).with(:all).returns(true)
    post :create, construct_params({}, params_hash.except(:user_id))
    assert_response :created
    @controller.unstub(:privilege?)
  end

  def test_create_with_other_user
    agent = other_agent
    post :create, construct_params({}, params_hash.merge(user_id: agent.id))
    assert_response :created
    match_json time_sheet_pattern(Helpdesk::TimeSheet.where(user_id: agent.id).first)
  end

  def test_update
    start_time = (Time.zone.now - 10.minutes).to_s
    executed_at = (Time.zone.now - 20.minutes).to_s
    ts = create_time_sheet(timer_running: false)
    freeze_time do
      put :update, construct_params({ id: ts.id }, time_spent: '03:00', start_time: start_time,
                                                   timer_running: true, executed_at: executed_at,
                                                   note: 'test note', billable: true, user_id: @agent.id)
      assert_response :success
      match_json time_sheet_pattern(ts.reload)
      match_json time_sheet_pattern({ time_spent: '03:00', start_time: utc_time(start_time.to_time),
                                      timer_running: false, executed_at: utc_time(executed_at.to_time),
                                      note: 'test note', billable: true }, ts)
    end
  end

  def test_update_numericality_invalid
    start_time = (Time.zone.now - 10.minutes).to_s
    executed_at = (Time.zone.now - 20.minutes).to_s
    ts = create_time_sheet(timer_running: false)
    put :update, construct_params({ id: ts.id },  time_spent: '03:00', start_time: start_time,
                                                  timer_running: true, executed_at: executed_at,
                                                  note: 'test note', billable: true, user_id: 'yu')
    assert_response :bad_request
    match_json([bad_request_error_pattern('user_id', 'is not a number')])
  end

  def test_update_presence_invalid
    start_time = (Time.zone.now - 10.minutes).to_s
    executed_at = (Time.zone.now - 20.minutes).to_s
    ts = create_time_sheet(timer_running: false)
    put :update, construct_params({ id: ts.id },  time_spent: '03:00', start_time: start_time,
                                                  timer_running: true, executed_at: executed_at,
                                                  note: 'test note', billable: true, user_id: '7878')
    assert_response :bad_request
    match_json([bad_request_error_pattern('user', "can't be blank")])
  end

  def test_update_date_time_invalid
    ts = create_time_sheet(timer_running: false)
    put :update, construct_params({ id: ts.id },  time_spent: '03:00', start_time: '67/23',
                                                  timer_running: true, executed_at: '89/12',
                                                  note: 'test note', billable: true)
    assert_response :bad_request
    match_json([bad_request_error_pattern('start_time', 'is not a date'),
                bad_request_error_pattern('executed_at', 'is not a date')])
  end

  def test_update_inclusion_invalid
    start_time = (Time.zone.now - 10.minutes).to_s
    executed_at = (Time.zone.now - 20.minutes).to_s
    ts = create_time_sheet(timer_running: false)
    put :update, construct_params({ id: ts.id },  time_spent: '03:00', start_time: start_time,
                                                  timer_running: '89', executed_at: executed_at,
                                                  note: 'test note', billable: '12')
    assert_response :bad_request
    match_json([bad_request_error_pattern('timer_running', 'Should be a value in the list 0,false,1,true'),
                bad_request_error_pattern('billable', 'Should be a value in the list 0,false,1,true')])
  end

  def test_update_format_invalid
    start_time = (Time.zone.now - 10.minutes).to_s
    executed_at = (Time.zone.now - 20.minutes).to_s
    ts = create_time_sheet(timer_running: false)
    put :update, construct_params({ id: ts.id },  time_spent: '08900', start_time: start_time,
                                                  timer_running: true, executed_at: executed_at,
                                                  note: 'test note', billable: true, user_id: @agent.id)
    assert_response :bad_request
    match_json([bad_request_error_pattern('time_spent', 'is not a valid time_spent')])
  end

  def test_update_start_time_greater_than_current_time
    start_time = (Time.zone.now + 20.hours).to_s
    executed_at = (Time.zone.now - 20.minutes).to_s
    ts = create_time_sheet(timer_running: false)
    put :update, construct_params({ id: ts.id },  time_spent: '09:00', start_time: start_time,
                                                  timer_running: true, executed_at: executed_at,
                                                  note: 'test note', billable: true, user_id: @agent.id)
    assert_response :bad_request
    match_json([bad_request_error_pattern('start_time', 'Has to be lesser than current time')])
  end

  def test_update_timer_running_true_again
    executed_at = (Time.zone.now - 20.minutes).to_s
    ts = create_time_sheet(timer_running: false)
    put :update, construct_params({ id: ts.id },  time_spent: '09:00',
                                                  timer_running: false, executed_at: executed_at,
                                                  note: 'test note', billable: true, user_id: @agent.id)
    assert_response :bad_request
    match_json([bad_request_error_pattern('timer_running', "Can't set to the same value as before")])
  end

  def test_update_timer_running_false_again
    executed_at = (Time.zone.now - 20.minutes).to_s
    ts = create_time_sheet(timer_running: true)
    put :update, construct_params({ id: ts.id },  time_spent: '09:00',
                                                  timer_running: true, executed_at: executed_at,
                                                  note: 'test note', billable: true, user_id: @agent.id)
    assert_response :bad_request
    match_json([bad_request_error_pattern('timer_running', "Can't set to the same value as before")])
  end

  def test_update_user_id_when_timer_running
    user = other_agent
    executed_at = (Time.zone.now - 20.minutes).to_s
    ts = create_time_sheet(timer_running: true)
    put :update, construct_params({ id: ts.id },  time_spent: '09:00', executed_at: executed_at,
                                                  note: 'test note', billable: true, user_id: user.id)
    assert_response :bad_request
    match_json([bad_request_error_pattern('user_id', "Can't update user when timer is running")])
  end

  def test_update_user_id_when_timer_not_running
    user = other_agent
    start_time = (Time.zone.now - 10.minutes).to_s
    executed_at = (Time.zone.now - 20.minutes).to_s
    ts = create_time_sheet(timer_running: false)
    freeze_time do
      put :update, construct_params({ id: ts.id }, time_spent: '01:00', executed_at: executed_at,
                                                   note: 'test note', billable: true, user_id: user.id)
      assert_response :success
      match_json time_sheet_pattern(ts.reload)
      match_json time_sheet_pattern({ time_spent: '01:00', user_id: user.id,
                                      timer_running: false, executed_at: utc_time(executed_at.to_time),
                                      note: 'test note', billable: true }, ts.reload)
    end
  end

  def test_update_user_id_and_timer_running_true_when_timer_is_not_running
    user = other_agent
    start_time = (Time.zone.now - 10.minutes).to_s
    executed_at = (Time.zone.now - 20.minutes).to_s
    ts = create_time_sheet(timer_running: false)
    freeze_time do
      put :update, construct_params({ id: ts.id }, time_spent: '01:00', timer_running: true,
                                                   executed_at: executed_at, note: 'test note', billable: true, user_id: user.id)
      assert_response :success
      match_json time_sheet_pattern(ts.reload)
      match_json time_sheet_pattern({ time_spent: '01:00', user_id: user.id,
                                      timer_running: true, executed_at: utc_time(executed_at.to_time),
                                      note: 'test note', billable: true }, ts.reload)
    end
  end

  def test_update_with_nullable_fields
    start_time = (Time.zone.now - 10.minutes).to_s
    executed_at = (Time.zone.now - 20.minutes).to_s
    ts = create_time_sheet(timer_running: true)
    freeze_time do
      put :update, construct_params({ id: ts.id }, time_spent: nil, timer_running: false,
                                                   executed_at: nil, note: 'test note', billable: true)
      assert_response :success
      match_json time_sheet_pattern(ts.reload)
      match_json time_sheet_pattern({ time_spent: '00:00',
                                      timer_running: false, executed_at: nil,
                                      note: 'test note', billable: true }, ts.reload)
    end
  end

  def test_update_start_time_when_timer_running_already
    start_time = (Time.zone.now - 10.minutes).to_s
    executed_at = (Time.zone.now - 20.minutes).to_s
    ts = create_time_sheet(timer_running: true)
    put :update, construct_params({ id: ts.id }, time_spent: '09:00', start_time: start_time,
                                                 executed_at: executed_at, note: 'test note', billable: true)
    assert_response :bad_request
    match_json([bad_request_error_pattern('start_time', 'Should be blank if timer_running was true already')])
  end

  def test_update_start_time_when_timer_is_not_running
    start_time = (Time.zone.now - 10.minutes).to_s
    executed_at = (Time.zone.now - 20.minutes).to_s
    ts = create_time_sheet(timer_running: false)
    put :update, construct_params({ id: ts.id }, time_spent: '09:00', start_time: start_time,
                                                 executed_at: executed_at, note: 'test note', billable: true)
    assert_response :bad_request
    match_json([bad_request_error_pattern('start_time', 'Should be blank if timer_running is false')])
  end

  def test_update_start_time_when_timer_running_is_set_to_true
    start_time = (Time.zone.now - 10.minutes).to_s
    executed_at = (Time.zone.now - 20.minutes).to_s
    ts = create_time_sheet(timer_running: false)
    freeze_time do
      put :update, construct_params({ id: ts.id }, time_spent: '09:42', timer_running: true, start_time: start_time,
                                                   executed_at: executed_at, note: 'test note', billable: true)
      assert_response :success
      match_json time_sheet_pattern(ts.reload)
      match_json time_sheet_pattern({ time_spent: '09:42', timer_running: true, executed_at: utc_time(executed_at.to_time),
                                      note: 'test note', billable: true, start_time: utc_time(start_time.to_time) }, ts.reload)
    end
  end

  def test_update_start_time_when_timer_running_is_set_to_false
    start_time = (Time.zone.now - 10.minutes).to_s
    executed_at = (Time.zone.now - 20.minutes).to_s
    ts = create_time_sheet(timer_running: true)
    put :update, construct_params({ id: ts.id }, time_spent: '09:00', start_time: start_time, timer_running: false,
                                                 executed_at: executed_at, note: 'test note', billable: true)
    assert_response :bad_request
    match_json([bad_request_error_pattern('start_time', 'Should be blank if timer_running was true already')])
  end

  def test_update_with_timer_running_true_valid
    executed_at = (Time.zone.now - 20.minutes).to_s
    ts = create_time_sheet(timer_running: false)
    freeze_time do
      put :update, construct_params({ id: ts.id }, timer_running: true,
                                                   executed_at: executed_at, note: 'test note', billable: true)
      assert_response :success
      match_json time_sheet_pattern(ts.reload)
      match_json time_sheet_pattern({ timer_running: true, executed_at: utc_time(executed_at.to_time),
                                      note: 'test note', billable: true, start_time: utc_time }, ts.reload)
    end
  end

  def test_update_with_timer_running_false_valid
    executed_at = (Time.zone.now - 20.minutes).to_s
    ts = create_time_sheet(timer_running: true)
    freeze_time do
      time_spent = (Time.zone.now - ts.start_time).abs.round
      if time_spent.is_a? Numeric
        hours, minutes = time_spent.divmod(60).first.divmod(60)
        time_spent = "#{sprintf('%0.02d', hours)}:#{sprintf('%0.02d', minutes)}"
      end
      put :update, construct_params({ id: ts.id }, timer_running: false,
                                                   executed_at: executed_at, note: 'test note', billable: true)
      assert_response :success
      match_json time_sheet_pattern(ts.reload)
      match_json time_sheet_pattern({ time_spent: time_spent, timer_running: false, executed_at: utc_time(executed_at.to_time),
                                      note: 'test note', billable: true }, ts.reload)
    end
  end

  def test_update_with_time_spent
    executed_at = (Time.zone.now - 20.minutes).to_s
    ts = create_time_sheet(timer_running: false)
    freeze_time do
      put :update, construct_params({ id: ts.id }, time_spent: '09:42', timer_running: true,
                                                   executed_at: executed_at, note: 'test note', billable: true)
      assert_response :success
      match_json time_sheet_pattern(ts.reload)
      match_json time_sheet_pattern({ time_spent: '09:42', timer_running: true, executed_at: utc_time(executed_at.to_time),
                                      note: 'test note', billable: true, start_time: utc_time }, ts.reload)
    end
  end

  def test_update_with_timer_running_false_and_time_spent
    executed_at = (Time.zone.now - 20.minutes).to_s
    ts = create_time_sheet(timer_running: true)
    freeze_time do
      put :update, construct_params({ id: ts.id }, time_spent: '09:42', timer_running: false,
                                                   executed_at: executed_at, note: 'test note', billable: true)
      assert_response :success
      match_json time_sheet_pattern(ts.reload)
      match_json time_sheet_pattern({ time_spent: '09:42', timer_running: false, executed_at: utc_time(executed_at.to_time),
                                      note: 'test note', billable: true }, ts.reload)
    end
  end

  def test_update_without_privilege
    ts = create_time_sheet(timer_running: true, user_id: other_agent.id)
    controller.class.any_instance.stubs(:privilege?).with(:all).returns(true).once
    User.any_instance.stubs(:privilege?).with(:edit_time_entries).returns(false).at_most_once
    put :update, construct_params({ id: ts.id }, time_spent: '09:00', note: 'test note', billable: true)
    assert_response :forbidden
    match_json(request_error_pattern('access_denied'))
    User.any_instance.unstub(:privilege?)
    controller.class.any_instance.unstub(:privilege?)
  end

  def test_update_without_feature
    ts = create_time_sheet(timer_running: true)
    controller.class.any_instance.stubs(:feature?).returns(false).once
    put :update, construct_params({ id: ts.id }, time_spent: '09:00', note: 'test note', billable: true)
    match_json(request_error_pattern('require_feature', feature: 'Timesheets'))
    assert_response :forbidden
    User.any_instance.stubs(:feature?)
  end

  def toggle_with_invalid_id
    put :toggle_timer, construct_params({ id: 99 }, test: 'junk')
  end

  def test_toggle_with_params
    put :toggle_timer, construct_params({ id: Helpdesk::TimeSheet.first }, test: 'junk')
    assert_response :bad_request
    match_json([bad_request_error_pattern('test', 'invalid_field')])
  end

  def test_toggle_off_timer
    timer = Helpdesk::TimeSheet.where(timer_running: true).first
    freeze_time do
      time = Time.zone.now - 1.hour - 23.minutes
      timer.update_column(:start_time, time)
      put :toggle_timer, construct_params({ id: timer.id }, {})
      assert_response :success
      match_json(time_sheet_pattern({ timer_running: false, time_spent: '01:23' }, timer.reload))
    end
  end

  def test_toggle_on_timer_with_other_timer_on
    timer_on = Helpdesk::TimeSheet.where(timer_running: true).first
    timer_off = Helpdesk::TimeSheet.where(timer_running: false).first
    Helpdesk::TimeSheet.update_all("user_id = #{@agent.id}", id: [timer_on.id, timer_off.id])
    put :toggle_timer, construct_params({ id: timer_off.id }, {})
    assert_response :success
    refute timer_on.reload.timer_running
    assert timer_off.reload.timer_running
  end

  def test_toggle_invalid_record
    ts = Helpdesk::TimeSheet.first
    Helpdesk::TimeSheet.any_instance.stubs(:update_attributes).returns(false)
    Helpdesk::TimeSheet.any_instance.stubs(:errors).returns([['user', "can't be blank"]])
    put :toggle_timer, construct_params({ id: ts.id }, {})
    assert_response :bad_request
    match_json([bad_request_error_pattern('user', "can't be blank")])
  end
end
