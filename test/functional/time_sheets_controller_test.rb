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
    {ticket_id: ticket.id, user_id: @agent.id}
  end

  def freeze_time(&block)
    time = Time.now
    Timecop.freeze(time)
    yield
    Timecop.return
  end

  def utc_time(time = Time.now)
    time.utc.as_json
  end

  def time_sheet(id)
    Helpdesk::TimeSheet.find_by_id(id)
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
    post :create, construct_params({}, {:test => 'junk'})
    assert_response :bad_request
    match_json [bad_request_error_pattern('test', 'invalid_field')]
  end

  def test_create_unpermitted_params
    @controller.stubs(:privilege?).with(:edit_time_entries).returns(false)
    @controller.stubs(:privilege?).with(:all).returns(true)
    post :create, construct_params({}, {:user_id => User.first.id})
    assert_response :bad_request
    match_json [bad_request_error_pattern('user_id', 'invalid_field')]
    @controller.unstub(:privilege?)
  end

  def test_create_start_time_and_timer_not_running
    post :create, construct_params({}, {:start_time => (Time.now + 10.minutes).as_json, 
      :timer_running => false}.merge(params_hash))
    assert_response :bad_request
    match_json [bad_request_error_pattern('start_time', 
      'Should be blank if timer_running is false')]
  end

  def test_create_with_no_params
    freeze_time do
      post :create, construct_params({}, params_hash)
      assert_response :created
      ts = time_sheet(parse_response(response.body)['id'])
      match_json time_sheet_pattern({timer_running: true, start_time: utc_time,
        executed_at: utc_time, time_spent: 0}, 
        ts)
      match_json time_sheet_pattern(ts)
    end
  end

  def test_create_with_start_time_only
    freeze_time do
      start_time = (Time.now + 10.minutes).as_json
      post :create, construct_params({}, {:start_time => start_time}.merge(params_hash))
      assert_response :created
      ts = time_sheet(parse_response(response.body)['id'])
      match_json time_sheet_pattern(ts) 
      match_json time_sheet_pattern({timer_running: true, start_time: utc_time(start_time.to_time),
      executed_at: utc_time, time_spent: 0}, 
      ts)
    end
  end

  def test_create_with_start_time_and_time_spent
    start_time = (Time.now + 10.minutes).as_json
    freeze_time do
      post :create, construct_params({}, {:start_time => start_time,
        :time_spent => '03:00'}.merge(params_hash))
      assert_response :created
      ts = time_sheet(parse_response(response.body)['id'])
      match_json time_sheet_pattern(ts)
      match_json time_sheet_pattern({start_time: utc_time(start_time.to_time), time_spent: 3,
        timer_running: true, executed_at: utc_time}, ts)
    end
  end

  def test_create_time_spent_only
    freeze_time do
      post :create, construct_params({}, {:time_spent => '03:00'}.merge(params_hash))
      assert_response :created
      ts = time_sheet(parse_response(response.body)['id'])
      match_json time_sheet_pattern({}, ts)
      match_json time_sheet_pattern({timer_running: false, time_spent: 3, start_time: utc_time,
        executed_at: utc_time}, ts)
    end
  end

  def test_create_with_timer_running_and_time_spent
    freeze_time do
      post :create, construct_params({}, {:time_spent => '03:00',
      :timer_running => false}.merge(params_hash))
      assert_response :created
      ts = time_sheet(parse_response(response.body)['id'])
      match_json time_sheet_pattern(ts)
      match_json time_sheet_pattern({time_spent: 3, timer_running: false, start_time: utc_time,
        executed_at: utc_time}, ts)
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
    start_time = (Time.now + 10.minutes).as_json
    executed_at = (Time.now + 20.minutes).as_json
    freeze_time do
      post :create, construct_params({}, {:time_spent => '03:00', :start_time => start_time,
        :timer_running => true, :executed_at => executed_at,
        :note => "test note", :billable => true, user_id: @agent.id}.merge(params_hash))
      assert_response :created
      ts = time_sheet(parse_response(response.body)['id'])
      match_json time_sheet_pattern(ts)
      match_json time_sheet_pattern({:time_spent => 3, :start_time => utc_time(start_time.to_time),
        :timer_running => false, :executed_at => utc_time(executed_at.to_time),
        :note => "test note", :billable => true}.merge(params_hash), ts)
    end
  end

end
