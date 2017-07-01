require_relative '../../test_helper'
['account_test_helper.rb', 'shared_ownership_test_helper'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
module Ember
  class TicketsControllerTest < ActionController::TestCase
    include TicketsTestHelper
    include TicketFieldsTestHelper
    include ProductsHelper
    include CompanyHelper
    include GroupHelper
    include QueryHashHelper
    include AccountTestHelper
    include SharedOwnershipTestHelper

    TAG_NAMES = Faker::Lorem.words(10).freeze

    CREATED_AT_OPTIONS = %w(
      any_time 5 15 30 60 240 720 1440
      today yesterday week last_week
      month last_month two_months six_months set_date
    ).freeze

    DROPDOWN_OPTIONS = Faker::Lorem.words(5).freeze

    DEPENDENT_FIELD_VALUES = {
      Faker::Address.country => {
        Faker::Address.state => [Faker::Address.city],
        Faker::Address.state => [Faker::Address.city]
      },
      Faker::Address.country => {
        Faker::Address.state => [Faker::Address.city],
        Faker::Address.state => [],
        Faker::Address.state => [Faker::Address.city, Faker::Address.city]
      }
    }.freeze

    def setup
      super
      before_all
    end

    @@before_all_run = false

    def before_all
      return if @@before_all_run
      @account.ticket_fields.custom_fields.each(&:destroy)
      create_dependent_custom_field(%w(test_custom_country test_custom_state test_custom_city))
      create_custom_field_dropdown('test_custom_dropdown', DROPDOWN_OPTIONS)
      10.times.each do |i|
        create_product
      end
      10.times.each do |i|
        create_company
      end
      10.times.each do |i|
        add_test_agent(@account, role: Role.find_by_name('Agent').id)
      end
      10.times.each do |i|
        create_group_with_agents(@account, agent_list: [@account.agents.sample.id])
      end

      50.times.each do |i|
        country = DEPENDENT_FIELD_VALUES.keys.sample
        state   = DEPENDENT_FIELD_VALUES[country].keys.sample
        city    = DEPENDENT_FIELD_VALUES[country][state].sample
        params = ticket_params_hash.except(:description).merge(custom_field: {})
        params[:custom_field]["test_custom_dropdown_#{@account.id}"] = [DROPDOWN_OPTIONS.sample, nil].sample
        params[:custom_field]["test_custom_country_#{@account.id}"]  = country
        params[:custom_field]["test_custom_state_#{@account.id}"]    = state
        params[:custom_field]["test_custom_city_#{@account.id}"]     = city
        params[:tag_names] = [TAG_NAMES.sample(rand(1..3)).join(','), nil].sample
        params[:responder_id] = [@account.agents.sample.id, nil].sample
        ticket = create_ticket(params)
        ticket.product = [@account.products.sample, nil].sample
        requester = [ticket.requester, nil].sample
        company_id = [@account.companies.sample.id, nil].sample
        requester.user_companies.create(company_id: company_id) if requester && company_id
        ticket.company_id = company_id
        ticket.save
      end
      @@before_all_run = true
    end

    def sample_arr(max = 4)
      (1..max).to_a.sample(rand(1..max))
    end

    def random_time(t1 = (Time.now - 1.year), t2 = Time.now)
      rand(t1..t2)
    end

    def filter_data_hash
      {
        'responder_id' => ['is_in', [@account.agents.map(&:id).sample(rand(1..3)), nil].sample],
        'requester_id' => ['is_in', [@account.contacts.map(&:id).sample(rand(1..3)), nil].sample],
        'owner_id' => ['is_in', [@account.companies.map(&:id).sample(rand(1..3)), nil].sample],
        'group_id' => ['is_in', [@account.groups.map(&:id).sample(rand(1..3)), nil].sample],
        'due_by' => ['due_by_op', [sample_arr(4), nil].sample],
        'status' => ['is_in', [@account.ticket_statuses.map(&:id).sample(rand(1..5)), nil].sample],
        'priority' => ['is_in', [sample_arr(4), nil].sample],
        'ticket_type' => ['is_in', [@account.ticket_type_values.map(&:value).sample(rand(1..5)), nil].sample],
        'source' => ['is_in', [sample_arr(11), nil].sample],
        'helpdesk_tags.name' => ['is_in', [TAG_NAMES.sample(rand(1..5)), nil].sample],
        'helpdesk_schema_less_tickets.product_id' => ['is_in', [@account.products.map(&:id).sample(rand(1..3)), nil].sample],
        'created_at' => ['is_greater_than', CREATED_AT_OPTIONS.sample],
        'test_custom_dropdown' => ['is_in', [DROPDOWN_OPTIONS.sample(rand(1..3)), nil].sample, 'custom_field']
      }.merge(dependent_filter_data_hash)
    end

    def dependent_filter_data_hash
      country = DEPENDENT_FIELD_VALUES.keys.sample
      state   = DEPENDENT_FIELD_VALUES[country].keys.sample
      city    = DEPENDENT_FIELD_VALUES[country][state].sample
      {
        'test_custom_country' => ['is_in', [country.dup], 'custom_field'],
        'test_custom_state' => ['is_in', [state.try(:dup)], 'custom_field'],
        'test_custom_city' => ['is_in', [city.try(:dup)], 'custom_field']
      }
    end

    def random_query_hash_params
      query_hash_params = {}
      data_hash = filter_data_hash.delete_if { |k, v| v[1].nil? }
      counter = 1
      data_hash.keys.sample(rand(1..14)).each do |filter|
        val = data_hash[filter]
        query_hash_params[counter.to_s] = query_hash_param(filter.dup, *val)
        counter += 1
      end
      query_hash_params
    end

    def query_hash_param(condition, operator, value, type = 'default')
      {
        'condition' => condition,
        'operator' => operator,
        'value' => value,
        'type' => type
      }
    end

    def ticket_params_hash
      subject = Faker::Lorem.words(10).join(' ')
      description = Faker::Lorem.paragraph
      email = Faker::Internet.email
      agent = [@account.agents.sample, nil].sample
      group_id = agent ? [agent.groups.sample.try(:id), nil].sample : nil
      created_at = rand((Time.now - 1.year)..(Time.now))
      due_by = rand((created_at - 2.days)..(created_at + 2.days))
      fr_due_by = due_by - 2.hours
      params_hash = {
        email: email, description: description, subject: subject,
        priority: rand(1..4), status: @account.ticket_statuses.map(&:id).sample,
        type: [@account.ticket_type_values.map(&:value).sample, nil].sample, responder_id: agent.try(:id),
        source: rand(1..11), due_by: due_by,
        fr_due_by: fr_due_by, group_id: group_id,
        created_at: created_at
      }
      params_hash
    end

    def test_agent_me_filter
      query_hash_params = { '0' => query_hash_param('responder_id', 'is_in', [0]) }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_agent_unassigned_filter
      query_hash_params = { '0' => query_hash_param('responder_id', 'is_in', [-1]) }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_agent_filter
      query_hash_params = { '0' => query_hash_param('responder_id', 'is_in', [@account.agents.sample.id]) }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_multiple_agents_filter
      query_hash_params = { '0' => query_hash_param('responder_id', 'is_in', @account.agents.map(&:id).sample(rand(1..3))) }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_my_groups_filter
      query_hash_params = { '0' => query_hash_param('group_id', 'is_in', [0]) }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_unassigned_group_filter
      query_hash_params = { '0' => query_hash_param('group_id', 'is_in', [-1]) }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_group_filter
      query_hash_params = { '0' => query_hash_param('group_id', 'is_in', [@account.groups.sample.id]) }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_multiple_groups_filter
      query_hash_params = { '0' => query_hash_param('group_id', 'is_in', @account.groups.map(&:id).sample(rand(1..3))) }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_overdue_filter
      query_hash_params = { '0' => query_hash_param('due_by', 'due_by_op', [1]) }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_today_dueby_filter
      query_hash_params = { '0' => query_hash_param('due_by', 'due_by_op', [2]) }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_tomorrow_dueby_filter
      query_hash_params = { '0' => query_hash_param('due_by', 'due_by_op', [3]) }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_next_8_hrs_dueby_filter
      query_hash_params = { '0' => query_hash_param('due_by', 'due_by_op', [4]) }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_all_unresolved_filter
      query_hash_params = { '0' => query_hash_param('status', 'is_in', [0]) }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_status_filter
      query_hash_params = { '0' => query_hash_param('status', 'is_in', [@account.ticket_statuses.sample.id]) }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_multiple_status_filter
      query_hash_params = { '0' => query_hash_param('status', 'is_in', @account.ticket_statuses.map(&:id).sample(rand(1..3))) }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_priority_filter
      query_hash_params = { '0' => query_hash_param('priority', 'is_in', [rand(1..4)]) }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_multiple_priority_filter
      query_hash_params = { '0' => query_hash_param('priority', 'is_in', sample_arr(4)) }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_none_type_filter
      query_hash_params = { '0' => query_hash_param('ticket_type', 'is_in', [-1]) }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_type_filter
      query_hash_params = { '0' => query_hash_param('ticket_type', 'is_in', [@account.ticket_type_values.sample.value]) }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_multiple_type_filter
      query_hash_params = { '0' => query_hash_param('ticket_type', 'is_in', @account.ticket_type_values.map(&:value).sample(rand(1..3))) }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_source_filter
      query_hash_params = { '0' => query_hash_param('source', 'is_in', [rand(1..11)]) }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_multiple_source_filter
      query_hash_params = { '0' => query_hash_param('source', 'is_in', sample_arr(11)) }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_tags_filter
      query_hash_params = { '0' => query_hash_param('helpdesk_tags.name', 'is_in', TAG_NAMES.sample(rand(1..3))) }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_customers_filter
      query_hash_params = { '0' => query_hash_param('owner_id', 'is_in', [@account.companies.sample.id]) }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_multiple_customers_filter
      query_hash_params = { '0' => query_hash_param('owner_id', 'is_in', @account.companies.map(&:id).sample(rand(1..3))) }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_requesters_filter
      query_hash_params = { '0' => query_hash_param('requester_id', 'is_in', [@account.contacts.sample.id]) }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_multiple_requesters_filter
      query_hash_params = { '0' => query_hash_param('requester_id', 'is_in', @account.contacts.map(&:id).sample(rand(1..3))) }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_none_products_filter
      query_hash_params = { '0' => query_hash_param('helpdesk_schema_less_tickets.product_id', 'is_in', [-1]) }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_products_filter
      query_hash_params = { '0' => query_hash_param('helpdesk_schema_less_tickets.product_id', 'is_in', [@account.products.sample.id]) }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_multiple_products_filter
      query_hash_params = { '0' => query_hash_param('helpdesk_schema_less_tickets.product_id', 'is_in', @account.products.map(&:id).sample(rand(1..3))) }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_custom_dropdown_filter
      query_hash_params = { '0' => query_hash_param('test_custom_dropdown', 'is_in', [DROPDOWN_OPTIONS.sample], 'custom_field') }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_multiple_custom_filter
      query_hash_params = { '0' => query_hash_param('test_custom_dropdown', 'is_in', DROPDOWN_OPTIONS.sample(3), 'custom_field') }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_dependent_field_one_level
      query_hash_params = { '0' => query_hash_param('test_custom_country', 'is_in', [DEPENDENT_FIELD_VALUES.keys.sample.dup], 'custom_field') }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_dependent_field_two_level
      country = DEPENDENT_FIELD_VALUES.keys.sample.dup
      state   = DEPENDENT_FIELD_VALUES[country].keys.sample.try(:dup)
      query_hash_params = {
        '0' => query_hash_param('test_custom_country', 'is_in', [country], 'custom_field'),
        '1' => query_hash_param('test_custom_state', 'is_in', [state], 'custom_field')
      }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_dependent_field_three_level
      country = DEPENDENT_FIELD_VALUES.keys.sample.dup
      state   = DEPENDENT_FIELD_VALUES[country].keys.sample.try(:dup)
      city    = DEPENDENT_FIELD_VALUES[country][state].sample.try(:dup)
      query_hash_params = {
        '0' => query_hash_param('test_custom_country', 'is_in', [country], 'custom_field'),
        '1' => query_hash_param('test_custom_state', 'is_in', [state], 'custom_field'),
        '2' => query_hash_param('test_custom_city', 'is_in', [city], 'custom_field')
      }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_default_custom_fields_filter
      query_hash_params = {
        '0' => query_hash_param('status', 'is_in', [2, 3]),
        '1' => query_hash_param('test_custom_dropdown', 'is_in', [DROPDOWN_OPTIONS.sample], 'custom_field')
      }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    def test_all_filters
      data_hash = filter_data_hash.delete_if { |k, v| v[1].nil? }
      query_hash_params = {}
      counter = 1
      data_hash.each do |k, v|
        query_hash_params[counter.to_s] = query_hash_param(k.dup, *v)
        counter += 1
      end
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
    end

    30.times.each do |i|
      define_method("test_multiple_filter_case_#{i + 1}") do
        query_hash_params = random_query_hash_params
        Rails.logger.debug "Method: test_multiple_filter_case_#{i + 1} :: params: #{random_query_hash_params.inspect}"
        get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
        assert_response 200
        match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
      end
    end

    def test_index_with_default_filter_id
      ticket_filter = @account.ticket_filters.find_by_name('Urgent and High priority Tickets')
      get :index, controller_params(version: 'private', filter: ticket_filter.id)
      assert_response 200
      match_json(private_api_ticket_index_filter_pattern(ticket_filter.data))
    end

    def test_index_with_custom_filter_id
      custom_filter = create_filter
      get :index, controller_params(version: 'private', filter: custom_filter.id)
      assert_response 200
      match_json(private_api_ticket_index_filter_pattern(custom_filter.data))
    end

    def test_index_with_order_clauses
      filter_params = { order_by: 'created_at', order_type: 'asc' }
      get :index, controller_params({ version: 'private' }.merge(filter_params))
      assert_response 200
      match_json(private_api_ticket_index_pattern(false, false, false, filter_params[:order_by], filter_params[:order_type]))
    end

    def test_tickets_shared_by_Internal_agent
      enable_feature(:shared_ownership) do
        initialize_internal_agent_with_default_internal_group

        ticket1 = create_ticket({:status => @status.status_id, :internal_agent_id => @internal_agent.id,
                                 :responder_id => @responding_agent.id}, nil, @internal_group)
        ticket2 = create_ticket({:status => 2, :responder_id => @responding_agent.id})
        login_as(@responding_agent)
        get :index, controller_params(version: 'private', filter: 'shared_by_me')

        assert_match /#{ticket1.subject}/, response.body
        assert_no_match /#{ticket2.subject}/, response.body

      end
    end

    def test_tickets_shared_with_Internal_agent
      enable_feature(:shared_ownership) do
        initialize_internal_agent_with_default_internal_group

        ticket1 = create_ticket({:status => @status.status_id, :internal_agent_id => @internal_agent.id,
                                 :responder_id => @responding_agent.id}, nil, @internal_group)
        ticket2 = create_ticket({:status => 2, :responder_id => @internal_agent.id})

        login_as(@internal_agent)

        get :index, controller_params(version: 'private', filter: 'shared_with_me')

        assert_match /#{ticket1.subject}/, response.body
        assert_no_match /#{ticket2.subject}/, response.body
      end
    end

    def test_filter_by_internal_agent_with_agent
      enable_feature(:shared_ownership) do
        initialize_internal_agent_with_default_internal_group

        ticket = create_ticket({:status => @status.status_id, :internal_agent_id => @internal_agent.id,
                                :responder_id => @responding_agent.id}, nil, @internal_group)
        query_hash_params = {'0' => query_hash_param('internal_agent_id', 'is_in', [@internal_agent.id])}
        get :index, controller_params({version: 'private', query_hash: query_hash_params}, false)

        assert_match /#{ticket.subject}/, response.body
      end
    end

    def test_filter_by_internal_group_with_group
      enable_feature(:shared_ownership) do
        initialize_internal_agent_with_default_internal_group

        ticket = create_ticket({:status => @status.status_id, :internal_agent_id => @internal_agent.id,
                                :responder_id => @responding_agent.id}, nil, @internal_group)


        query_hash_params = {'0' => query_hash_param('internal_group_id', 'is_in', [@internal_group.id])}
        get :index, controller_params({version: 'private', query_hash: query_hash_params}, false)

        assert_match /#{ticket.subject}/, response.body
      end
    end

    def test_filter_by_any_agent_with_agent
      enable_feature(:shared_ownership) do
        initialize_internal_agent_with_default_internal_group

        ticket = create_ticket({:status => @status.status_id, :internal_agent_id => @internal_agent.id,
                                :responder_id => @responding_agent.id}, nil, @internal_group)

        query_hash_params = {'0' => query_hash_param('any_agent_id', 'is_in', [@internal_agent.id])}
        get :index, controller_params({version: 'private', query_hash: query_hash_params}, false)

        assert_match /#{ticket.subject}/, response.body
      end
    end

    def test_filter_by_any_group_with_group
      enable_feature(:shared_ownership) do
        initialize_internal_agent_with_default_internal_group

        ticket = create_ticket({:status => @status.status_id, :internal_agent_id => @internal_agent.id,
                                :responder_id => @responding_agent.id}, nil, @internal_group)

        query_hash_params = {'0' => query_hash_param('any_group_id', 'is_in', [@internal_group.id])}
        get :index, controller_params({version: 'private', query_hash: query_hash_params}, false)

        assert_match /#{ticket.subject}/, response.body
      end
    end

    def test_filter_by_internal_agent_and_internal_group_with_agent_and_group
      enable_feature(:shared_ownership) do
        initialize_internal_agent_with_default_internal_group

        ticket1 = create_ticket({:status => @status.status_id, :internal_agent_id => @internal_agent.id,
                                 :responder_id => @responding_agent.id}, nil, @internal_group)
        ticket2 = create_ticket({:status => 2, :responder_id => @internal_agent.id}, group = @internal_group)

        query_hash_params = {'0' => query_hash_param('internal_agent_id', 'is_in', [@internal_agent.id]),
                             '1' => query_hash_param('internal_group_id', 'is_in', [@internal_group.id])}
        get :index, controller_params({version: 'private', query_hash: query_hash_params}, false)
        assert_match /#{ticket1.subject}/, response.body
        assert_no_match /#{ticket2.subject}/, response.body
      end
    end

    def test_filter_by_any_agent_and_any_group_with_agent_and_group
      enable_feature(:shared_ownership) do
        initialize_internal_agent_with_default_internal_group

        ticket1 = create_ticket({:status => @status.status_id, :internal_agent_id => @internal_agent.id,
                                 :responder_id => @responding_agent.id}, nil, @internal_group)
        ticket2 = create_ticket({:status => 2, :responder_id => @internal_agent.id}, group = @internal_group)

        query_hash_params = {'0' => query_hash_param('any_agent_id', 'is_in', [@internal_agent.id]),
                             '1' => query_hash_param('any_group_id', 'is_in', [@internal_group.id])}
        get :index, controller_params({version: 'private', query_hash: query_hash_params}, false)

        assert_match /#{ticket1.subject}/, response.body
        assert_match /#{ticket2.subject}/, response.body
      end
    end

    def test_filter_by_any_agent_and_any_group_with_agent
      enable_feature(:shared_ownership) do
        initialize_internal_agent_with_default_internal_group

        ticket1 = create_ticket({:status => @status.status_id, :internal_agent_id => @internal_agent.id,
                                 :responder_id => @responding_agent.id}, nil, @internal_group)
        ticket2 = create_ticket({:status => 2, :responder_id => @responding_agent.id}, group = @internal_group)

        query_hash_params = {'0' => query_hash_param('any_agent_id', 'is_in', [@internal_agent.id])}
        get :index, controller_params({version: 'private', query_hash: query_hash_params}, false)

        assert_match /#{ticket1.subject}/, response.body
        assert_no_match /#{ticket2.subject}/, response.body
      end
    end

    # Tickets list without any filter and query_hash should get all tickets without created_at limit
    def test_index_empty_query_hash
      filter_params = { query_hash: '', include: 'count' }
      get :index, controller_params({ version: 'private' }.merge(filter_params))
      assert_response 200
      match_json(private_api_ticket_index_pattern(false, false, false, 'created_at', 'desc', true))
      assert response.api_meta[:count] == @account.tickets.where(spam: false, deleted: false).count
    end
  end
end
