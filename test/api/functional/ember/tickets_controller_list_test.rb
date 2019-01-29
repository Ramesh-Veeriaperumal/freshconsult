require_relative '../../test_helper'
['account_test_helper.rb', 'shared_ownership_test_helper'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
module Ember
  class TicketsControllerTest < ActionController::TestCase
    include ApiTicketsTestHelper
    include TicketFieldsTestHelper
    include ProductsHelper
    include CompanyHelper
    include GroupHelper
    include QueryHashHelper
    include Redis::RedisKeys
    include Redis::OthersRedis
    include AccountTestHelper
    include SharedOwnershipTestHelper

    CREATED_AT_OPTIONS = %w(
      any_time 5 15 30 60 240 720 1440
      today yesterday week last_week
      month last_month two_months six_months
    ).freeze

    def setup
      super
      @private_api = true
      Sidekiq::Worker.clear_all
      MixpanelWrapper.stubs(:send_to_mixpanel).returns(true)
      Account.any_instance.stubs(:sla_management_v2_enabled?).returns(true)
      Account.current.features.es_v2_writes.destroy
      Account.current.time_zone = Time.zone.name
      Account.current.save
      User.current.time_zone = Time.zone.name
      User.current.save
      Account.current.reload
      @account.sections.map(&:destroy)
      tickets_controller_before_all(@@before_all_run)
      @@before_all_run=true unless @@before_all_run
    end

    @@before_all_run=false

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
        'association_type' => ['is_in', [sample_arr(4), nil].sample],
        'created_at' => ['is_greater_than', CREATED_AT_OPTIONS.sample],
        'test_custom_dropdown' => ['is_in', [DROPDOWN_OPTIONS.sample(rand(1..3))].sample, 'custom_field']
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

    def match_db_and_es_query_responses(query_hash_params)
      # Runs on DB and fetches records
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
      # Checks for ES response
      match_query_response_with_es_enabled(query_hash_params)
    end

    def match_db_and_es_filter_responses(ticket_filter)
      get :index, controller_params(version: 'private', filter: ticket_filter.id)
      assert_response 200
      match_json(private_api_ticket_index_filter_pattern(ticket_filter.data))
      match_query_response_with_es_enabled(ticket_filter.data)
    end

    def match_query_response_with_es_enabled(query_hash_params)
      enable_es_api_load(query_hash_params) do
        response_stub = filter_factory_es_cluster_response_stub(query_hash_params)
        SearchService::Client.any_instance.stubs(:query).returns(SearchService::Response.new(response_stub))
        SearchService::Response.any_instance.stubs(:records).returns(JSON.parse(response_stub))
        get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
        assert_response 200
        match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
      end
    end

    def match_filter_response_with_es_enabled(ticket_filter)
      enable_es_api_load(ticket_filter) do
        response_stub = filter_factory_filter_es_response_stub(ticket_filter.data)
        SearchService::Client.any_instance.stubs(:query).returns(SearchService::Response.new(response_stub))
        SearchService::Response.any_instance.stubs(:records).returns(JSON.parse(response_stub))
        get :index, controller_params(version: 'private', filter: ticket_filter.id)
        assert_response 200
        match_json(private_api_ticket_index_filter_pattern(ticket_filter.data))
      end
    end

    def match_custom_query_response_with_es_enabled(query_hash_params, order_by = 'created_at')
      enable_es_api_load(query_hash_params) do
        response_stub = filter_factory_es_cluster_query_response_stub(query_hash_params, order_by)
        SearchService::Client.any_instance.stubs(:query).returns(SearchService::Response.new(response_stub))
        SearchService::Response.any_instance.stubs(:records).returns(JSON.parse(response_stub))
        get :index, controller_params({ version: 'private', query_hash: query_hash_params, order_by: order_by }, false)
        assert_response 200

        match_json(private_api_ticket_index_query_hash_pattern(query_hash_params))
      end
    end

    def match_default_filter_response_with_es_enabled(filter_name)
      enable_es_api_load(filter_name) do
        response_stub = filter_factory_default_filter_es_response_stub(filter_name)
        SearchService::Client.any_instance.stubs(:query).returns(SearchService::Response.new(response_stub))
        SearchService::Response.any_instance.stubs(:records).returns(JSON.parse(response_stub))
        get :index, controller_params({ version: 'private', filter: filter_name }, false)
        assert_response 200

        match_json(private_api_ticket_index_default_filter_pattern(filter_name))
      end
    end

    def match_order_query_with_es_enabled(order_params, all_tickets = false)
      enable_es_api_load(order_params) do
        response_stub = filter_factory_order_response_stub(order_params[:order_by], order_params[:order_type], all_tickets)
        SearchService::Client.any_instance.stubs(:query).returns(SearchService::Response.new(response_stub))
        SearchService::Response.any_instance.stubs(:records).returns(JSON.parse(response_stub))
        get :index, controller_params({ version: 'private' }.merge(order_params))
        assert_response 200
        match_json(private_api_ticket_index_pattern(false, false, false, order_params[:order_by], order_params[:order_type], all_tickets))
      end
    end

    def enable_es_api_load(params, &block)
      Account.current.launch(:new_es_api)
      yield if block_given?
      Account.current.rollback(:new_es_api)
    end

    def test_skill_filter
      enable_adv_ticketing([:skill_based_round_robin]) do
        create_skill_tickets
        query_hash_params = { '0' => query_hash_param('sl_skill_id', 'is_in', [@account.skills.sample.id]) }
        match_db_and_es_query_responses(query_hash_params)
      end
    end

    def test_multiple_skills_filter
      enable_adv_ticketing([:skill_based_round_robin]) do
        create_skill_tickets
        query_hash_params = { '0' => query_hash_param('sl_skill_id', 'is_in', @account.skills.map(&:id).sample(rand(1..2))) }
        match_db_and_es_query_responses(query_hash_params)
      end
    end

    def test_agent_me_filter
      query_hash_params = { '0' => query_hash_param('responder_id', 'is_in', [0]) }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_agent_unassigned_filter
      query_hash_params = { '0' => query_hash_param('responder_id', 'is_in', [-1]) }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_agent_filter
      query_hash_params = { '0' => query_hash_param('responder_id', 'is_in', [@account.agents.sample.id]) }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_multiple_agents_filter
      query_hash_params = { '0' => query_hash_param('responder_id', 'is_in', @account.agents.map(&:id).sample(rand(1..3))) }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_my_groups_filter
      query_hash_params = { '0' => query_hash_param('group_id', 'is_in', [0]) }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_unassigned_group_filter
      query_hash_params = { '0' => query_hash_param('group_id', 'is_in', [-1]) }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_group_filter
      query_hash_params = { '0' => query_hash_param('group_id', 'is_in', [@account.groups.sample.id]) }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_multiple_groups_filter
      query_hash_params = { '0' => query_hash_param('group_id', 'is_in', @account.groups.map(&:id).sample(rand(1..3))) }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_overdue_filter
      query_hash_params = { '0' => query_hash_param('due_by', 'due_by_op', [1]) }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_today_dueby_filter
      query_hash_params = { '0' => query_hash_param('due_by', 'due_by_op', [2]) }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_tomorrow_dueby_filter
      query_hash_params = { '0' => query_hash_param('due_by', 'due_by_op', [3]) }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_next_8_hrs_dueby_filter
      query_hash_params = { '0' => query_hash_param('due_by', 'due_by_op', [4]) }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_all_unresolved_filter
      query_hash_params = { '0' => query_hash_param('status', 'is_in', [0]) }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_status_filter
      query_hash_params = { '0' => query_hash_param('status', 'is_in', [@account.ticket_statuses.sample.id]) }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_multiple_status_filter
      query_hash_params = { '0' => query_hash_param('status', 'is_in', @account.ticket_statuses.map(&:id).sample(rand(1..3))) }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_priority_filter
      query_hash_params = { '0' => query_hash_param('priority', 'is_in', [rand(1..4)]) }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_multiple_priority_filter
      query_hash_params = { '0' => query_hash_param('priority', 'is_in', sample_arr(4)) }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_none_type_filter
      query_hash_params = { '0' => query_hash_param('ticket_type', 'is_in', [-1]) }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_type_filter
      query_hash_params = { '0' => query_hash_param('ticket_type', 'is_in', [@account.ticket_type_values.sample.value]) }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_multiple_type_filter
      query_hash_params = { '0' => query_hash_param('ticket_type', 'is_in', @account.ticket_type_values.map(&:value).sample(rand(1..3))) }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_source_filter
      query_hash_params = { '0' => query_hash_param('source', 'is_in', [rand(1..11)]) }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_multiple_source_filter
      query_hash_params = { '0' => query_hash_param('source', 'is_in', sample_arr(11)) }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_tags_filter
      query_hash_params = { '0' => query_hash_param('helpdesk_tags.name', 'is_in', TAG_NAMES.sample(rand(1..3))) }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_customers_filter
      query_hash_params = { '0' => query_hash_param('owner_id', 'is_in', [@account.companies.sample.id]) }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_multiple_customers_filter
      query_hash_params = { '0' => query_hash_param('owner_id', 'is_in', @account.companies.map(&:id).sample(rand(1..3))) }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_requesters_filter
      query_hash_params = { '0' => query_hash_param('requester_id', 'is_in', [@account.contacts.sample.id]) }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_multiple_requesters_filter
      query_hash_params = { '0' => query_hash_param('requester_id', 'is_in', @account.contacts.map(&:id).sample(rand(1..3))) }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_none_products_filter
      query_hash_params = { '0' => query_hash_param('helpdesk_schema_less_tickets.product_id', 'is_in', [-1]) }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_products_filter
      query_hash_params = { '0' => query_hash_param('helpdesk_schema_less_tickets.product_id', 'is_in', [@account.products.sample.id]) }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_multiple_products_filter
      query_hash_params = { '0' => query_hash_param('helpdesk_schema_less_tickets.product_id', 'is_in', @account.products.map(&:id).sample(rand(1..3))) }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_custom_dropdown_filter
      query_hash_params = { '0' => query_hash_param('test_custom_dropdown', 'is_in', [DROPDOWN_OPTIONS.sample], 'custom_field') }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_multiple_custom_filter
      query_hash_params = { '0' => query_hash_param('test_custom_dropdown', 'is_in', DROPDOWN_OPTIONS.sample(3), 'custom_field') }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_dependent_field_one_level
      query_hash_params = { '0' => query_hash_param('test_custom_country', 'is_in', [DEPENDENT_FIELD_VALUES.keys.sample.dup], 'custom_field') }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_dependent_field_two_level
      country = DEPENDENT_FIELD_VALUES.keys.sample.dup
      state   = DEPENDENT_FIELD_VALUES[country].keys.sample.try(:dup)
      query_hash_params = {
        '0' => query_hash_param('test_custom_country', 'is_in', [country], 'custom_field'),
        '1' => query_hash_param('test_custom_state', 'is_in', [state], 'custom_field')
      }
      match_db_and_es_query_responses(query_hash_params)
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
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_default_custom_fields_filter
      query_hash_params = {
        '0' => query_hash_param('status', 'is_in', [2, 3]),
        '1' => query_hash_param('test_custom_dropdown', 'is_in', [DROPDOWN_OPTIONS.sample], 'custom_field')
      }
      match_db_and_es_query_responses(query_hash_params)
    end

    def test_all_filters
      data_hash = filter_data_hash.delete_if { |k, v| v[1].nil? }
      query_hash_params = {}
      counter = 1
      data_hash.each do |k, v|
        query_hash_params[counter.to_s] = query_hash_param(k.dup, *v)
        counter += 1
      end
      enable_adv_ticketing(%i[link_tickets parent_child_tickets skill_based_round_robin]) do
        match_db_and_es_query_responses(query_hash_params)
      end
    end

    30.times.each do |i|
      define_method("test_multiple_filter_case_#{i + 1}") do
        query_hash_params = random_query_hash_params
        Rails.logger.debug "Method: test_multiple_filter_case_#{i + 1} :: params: #{query_hash_params.inspect}"
        enable_adv_ticketing(%i[link_tickets parent_child_tickets]) do
          match_db_and_es_query_responses(query_hash_params)
        end
      end
    end

    def test_index_with_default_filter_id
      ticket_filter = @account.ticket_filters.find_by_name('Urgent and High priority Tickets')
      get :index, controller_params(version: 'private', filter: ticket_filter.id)
      assert_response 200
      match_json(private_api_ticket_index_filter_pattern(ticket_filter.data))

      match_filter_response_with_es_enabled(ticket_filter)
    end

    def test_index_with_custom_filter_id
      custom_filter = create_filter
      get :index, controller_params(version: 'private', filter: custom_filter.id)
      assert_response 200
      match_json(private_api_ticket_index_filter_pattern(custom_filter.data))

      match_filter_response_with_es_enabled(custom_filter)
    end

    def test_index_with_order_clauses
      filter_params = { order_by: 'created_at', order_type: 'asc' }
      get :index, controller_params({ version: 'private' }.merge(filter_params))
      assert_response 200
      match_json(private_api_ticket_index_pattern(false, false, false, filter_params[:order_by], filter_params[:order_type]))

      match_order_query_with_es_enabled(filter_params)
    end

    def test_index_with_customer_response_order_clauses
      MixpanelWrapper.stubs(:send_to_mixpanel).returns(true)
      query_hash_params = { '0' => query_hash_param('responder_id', 'is_in', [0]) }
      @account.features.sort_by_customer_response.create
      @account.features.reload
      get :index, controller_params({ version: 'private', query_hash: query_hash_params, order_by: 'requester_responded_at' }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params, wf_order = 'requester_responded_at'))

      match_custom_query_response_with_es_enabled(query_hash_params, 'requester_responded_at')
    ensure
      @account.features.sort_by_customer_response.destroy
      MixpanelWrapper.unstub(:send_to_mixpanel)
    end

    def test_index_with_agent_response_order_clauses
      MixpanelWrapper.stubs(:send_to_mixpanel).returns(true)
      query_hash_params = { '0' => query_hash_param('responder_id', 'is_in', [0]) }
      @account.features.sort_by_customer_response.create
      @account.features.reload
      get :index, controller_params({ version: 'private', query_hash: query_hash_params, order_by: 'agent_responded_at' }, false)
      assert_response 200
      match_json(private_api_ticket_index_query_hash_pattern(query_hash_params, 'agent_responded_at'))

      match_custom_query_response_with_es_enabled(query_hash_params, 'agent_responded_at')
    ensure
      @account.features.sort_by_customer_response.destroy
      MixpanelWrapper.unstub(:send_to_mixpanel)
    end

    def test_tickets_shared_by_internal_agent
      @account.add_feature :shared_ownership
      initialize_internal_agent_with_default_internal_group

      ticket1 = create_ticket({ status: @status.status_id, internal_agent_id: @internal_agent.id,
                                responder_id: @responding_agent.id }, nil, @internal_group)
      ticket2 = create_ticket(status: 2, responder_id: @responding_agent.id)
      login_as(@responding_agent)
      get :index, controller_params(version: 'private', filter: 'shared_by_me')
      assert_response 200
      match_json(private_api_ticket_index_default_filter_pattern('shared_by_me'))

      match_default_filter_response_with_es_enabled('shared_by_me')
    end

    def test_tickets_shared_with_internal_agent
      @account.add_feature :shared_ownership
      initialize_internal_agent_with_default_internal_group

      ticket1 = create_ticket({ status: @status.status_id, internal_agent_id: @internal_agent.id,
                                responder_id: @responding_agent.id }, nil, @internal_group)
      ticket2 = create_ticket({ status: 2, responder_id: @internal_agent.id })

      login_as(@internal_agent)
      get :index, controller_params(version: 'private', filter: 'shared_with_me')
      assert_response 200
      match_json(private_api_ticket_index_default_filter_pattern('shared_with_me'))

      match_default_filter_response_with_es_enabled('shared_with_me')
    end

    def test_filter_by_internal_agent_with_agent
      enable_feature(:shared_ownership) do
        initialize_internal_agent_with_default_internal_group
        ticket = create_ticket({ status: @status.status_id, internal_agent_id: @internal_agent.id,
                                 responder_id: @responding_agent.id }, nil, @internal_group)
        query_hash_params = { '0' => query_hash_param('internal_agent_id', 'is_in', [@internal_agent.id]) }

        match_db_and_es_query_responses(query_hash_params)
      end
    end

    def test_filter_by_internal_group_with_group
      enable_feature(:shared_ownership) do
        initialize_internal_agent_with_default_internal_group
        ticket = create_ticket({ status: @status.status_id, internal_agent_id: @internal_agent.id,
                                 responder_id: @responding_agent.id }, nil, @internal_group)
        query_hash_params = { '0' => query_hash_param('internal_group_id', 'is_in', [@internal_group.id]) }

        match_db_and_es_query_responses(query_hash_params)
      end
    end

    def test_filter_by_any_agent_with_agent
      enable_feature(:shared_ownership) do
        initialize_internal_agent_with_default_internal_group
        ticket = create_ticket({ status: @status.status_id, internal_agent_id: @internal_agent.id,
                                 responder_id: @responding_agent.id }, nil, @internal_group)
        query_hash_params = { '0' => query_hash_param('any_agent_id', 'is_in', [@internal_agent.id]) }

        match_db_and_es_query_responses(query_hash_params)
      end
    end

    def test_filter_by_any_group_with_group
      enable_feature(:shared_ownership) do
        initialize_internal_agent_with_default_internal_group
        ticket = create_ticket({ status: @status.status_id, internal_agent_id: @internal_agent.id,
                                 responder_id: @responding_agent.id }, nil, @internal_group)

        query_hash_params = { '0' => query_hash_param('any_group_id', 'is_in', [@internal_group.id]) }

        match_db_and_es_query_responses(query_hash_params)
      end
    end

    def test_filter_by_internal_agent_and_internal_group_with_agent_and_group
      enable_feature(:shared_ownership) do
        initialize_internal_agent_with_default_internal_group
        ticket1 = create_ticket({ status: @status.status_id, internal_agent_id: @internal_agent.id,
                                  responder_id: @responding_agent.id }, nil, @internal_group)
        ticket2 = create_ticket({ status: 2, responder_id: @internal_agent.id }, group = @internal_group)

        query_hash_params = {
          '0' => query_hash_param('internal_agent_id', 'is_in', [@internal_agent.id]),
          '1' => query_hash_param('internal_group_id', 'is_in', [@internal_group.id])
        }

        match_db_and_es_query_responses(query_hash_params)
      end
    end

    def test_filter_by_any_agent_and_any_group_with_agent_and_group
      enable_feature(:shared_ownership) do
        initialize_internal_agent_with_default_internal_group
        ticket1 = create_ticket({ status: @status.status_id, internal_agent_id: @internal_agent.id,
                                  responder_id: @responding_agent.id }, nil, @internal_group)
        ticket2 = create_ticket({ status: 2, responder_id: @internal_agent.id }, group = @internal_group)

        query_hash_params = {
          '0' => query_hash_param('any_agent_id', 'is_in', [@internal_agent.id]),
          '1' => query_hash_param('any_group_id', 'is_in', [@internal_group.id])
        }

        match_db_and_es_query_responses(query_hash_params)
      end
    end

    def test_filter_by_any_agent_and_any_group_with_agent
      enable_feature(:shared_ownership) do
        initialize_internal_agent_with_default_internal_group
        ticket1 = create_ticket({ status: @status.status_id, internal_agent_id: @internal_agent.id,
                                  responder_id: @responding_agent.id }, nil, @internal_group)
        ticket2 = create_ticket({ status: 2, responder_id: @responding_agent.id }, group = @internal_group)

        query_hash_params = { '0' => query_hash_param('any_agent_id', 'is_in', [@internal_agent.id]) }

        match_db_and_es_query_responses(query_hash_params)
      end
    end

    # Tickets list without any filter and query_hash should get all tickets without created_at limit
    def test_index_empty_query_hash
      filter_params = { query_hash: '' }
      get :index, controller_params({ version: 'private' }.merge(filter_params))
      assert_response 200
      match_json(private_api_ticket_index_pattern(false, false, false, 'created_at', 'desc', true))

      match_order_query_with_es_enabled({ query_hash: '', order_by: 'created_at', order_type: 'desc' }, true)
    end

    # Tickets list spam / trash should have emptying_on_background flag about background job in its meta
    def test_index_empty_spam_meta_notice
      filter_params = { filter: 'spam' }
      empty_spam_key = EMPTY_SPAM_TICKETS % { account_id: Account.current.id }
      remove_others_redis_key(empty_spam_key)
      get :index, controller_params({ version: 'private' }.merge(filter_params))
      assert_response 200
      match_json(private_api_ticket_index_spam_deleted_pattern(true))
      assert response.api_meta.key?(:emptying_on_background) && !response.api_meta[:emptying_on_background]

      match_default_filter_response_with_es_enabled('spam')
    end

    def test_index_empty_trash_meta_notice
      filter_params = { filter: 'deleted' }
      empty_trash_key = EMPTY_TRASH_TICKETS % { account_id: Account.current.id }
      remove_others_redis_key(empty_trash_key)
      get :index, controller_params({ version: 'private' }.merge(filter_params))
      assert_response 200
      match_json(private_api_ticket_index_spam_deleted_pattern(false, true))
      assert response.api_meta.key?(:emptying_on_background) && !response.api_meta[:emptying_on_background]

      match_default_filter_response_with_es_enabled('deleted')
    end

    def test_index_other_fields_must_not_have_the_notice_key
      ticket_filter = @account.ticket_filters.find_by_name('Urgent and High priority Tickets')
      get :index, controller_params(version: 'private', filter: ticket_filter.id)
      assert_response 200
      match_json(private_api_ticket_index_filter_pattern(ticket_filter.data))
      assert !response.api_meta.key?(:emptying_on_background)

      match_filter_response_with_es_enabled(ticket_filter)
    end

    def test_index_empty_spam_notice_should_be_true
      filter_params = { filter: 'spam' }
      empty_spam_key = EMPTY_SPAM_TICKETS % { account_id: Account.current.id }
      set_others_redis_key(empty_spam_key, true)
      get :index, controller_params({ version: 'private' }.merge(filter_params))
      assert_response 200
      match_json(private_api_ticket_index_spam_deleted_pattern(true))
      assert response.api_meta[:emptying_on_background]

      match_default_filter_response_with_es_enabled('spam')
    ensure
      remove_others_redis_key(empty_spam_key)
    end

    def test_index_empty_spam_notice_should_be_false
      filter_params = { filter: 'spam' }
      empty_spam_key = EMPTY_SPAM_TICKETS % { account_id: Account.current.id }
      remove_others_redis_key(empty_spam_key)
      get :index, controller_params({ version: 'private' }.merge(filter_params))
      assert_response 200
      match_json(private_api_ticket_index_spam_deleted_pattern(true))
      assert !response.api_meta[:emptying_on_background]

      match_default_filter_response_with_es_enabled('spam')
    end

    def test_index_with_page_greater_than_limit
      get :index, controller_params(version: 'private', page: ApiTicketConstants::MAX_PAGE_LIMIT + 4)
      assert_response 400
    end

    def test_access_tickets_controller_with_jwt_token
      user = User.current
      custom_filter = create_filter
      UserSession.any_instance.unstub(:cookie_credentials)
      log_out
      token = get_mobile_jwt_token_of_user(@agent)
      bearer_token = "Bearer #{token}"
      current_header = request.env['HTTP_AUTHORIZATION']
      request.env['HTTP_USER_AGENT'] = 'Freshdesk_Native'
      set_custom_jwt_header(bearer_token)
      get :index, controller_params(version: 'private', filter: custom_filter.id)
      # get :index, controller_params(version: 'private', per_page: 50)
      assert_response 200
      request.env['HTTP_AUTHORIZATION'] = current_header
      UserSession.any_instance.stubs(:cookie_credentials).returns([user.persistence_token, user.id])
      login_as(user)
      user.make_current
    end

    def test_access_tickets_controller_with_invalid_jwt_token
      user = User.current
      custom_filter = create_filter
      UserSession.any_instance.unstub(:cookie_credentials)
      log_out
      bearer_token = 'Bearer AAAAAAA'
      current_header = request.env['HTTP_AUTHORIZATION']
      request.env['HTTP_USER_AGENT'] = 'Freshdesk_Native'
      set_custom_jwt_header(bearer_token)
      get :index, controller_params(version: 'private', filter: custom_filter.id)
      # get :index, controller_params(version: 'private', per_page: 50)
      assert_response 401
      UserSession.any_instance.stubs(:cookie_credentials).returns([user.persistence_token, user.id])
      request.env['HTTP_AUTHORIZATION'] = current_header
      login_as(user)
      user.make_current
    end
  end
end
