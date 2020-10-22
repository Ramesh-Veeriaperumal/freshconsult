require_relative '../../../test_helper'
require 'webmock/minitest'
['social_tickets_creation_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

module Channel::V2
  class TicketsControllerTest < ActionController::TestCase
    include ApiTicketsTestHelper
    include SocialTicketsCreationHelper
    include TicketFiltersHelper
    include CentralLib::CentralResyncHelper
    include CentralLib::CentralResyncConstants
    include Redis::OthersRedis

    CUSTOM_FIELDS = %w[number checkbox decimal text paragraph dropdown country state city date].freeze
    CHANNEL_SOURCE = 'analytics'.freeze

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

    def fb_page_params_hash
      {
        :profile_id=>Faker::Number.number(15),
        :access_token=>Faker::Lorem.characters,
        :page_id=>Faker::Number.number(15),
        :page_name=>Faker::Name.name,
        :page_token=>Faker::Lorem.characters,
        :page_img_url=>Faker::Internet.url,
        :page_link=>Faker::Internet.url,
        :fetch_since=>0,
        :reauth_required=>false,
        :last_error=>nil,
        :message_since=>1544533381,
        :enable_page=>true,
        :realtime_messaging=>0
      }
    end

    def get_user_with_default_company
      user_company = @account.user_companies.group(:user_id).having('count(*) = 1 ').last
      if user_company.present?
        user_company.user
      else
        new_user = add_new_user(@account)
        new_user.user_companies.create(:company_id => get_company.id, :default => true)
        new_user.reload
      end
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
    ensure
      Account.any_instance.unstub(:shared_ownership_enabled?)
    end

    def test_index_with_jwt
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      Helpdesk::Ticket.update_all(created_at: 2.months.ago)
      Helpdesk::Ticket.first.update_attributes(created_at: 1.month.ago,
                                               deleted: false, spam: false)
      get :index, controller_params(version: 'channel')
      assert_response 200
      response = parse_response @response.body
      assert_equal 1, response.size
    ensure
      @channel_v2_api = false
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_create_with_jwt
      created_at = updated_at = Time.zone.now
      params = {
        requester_id: requester.id, status: 2, priority: 2,
        subject: Faker::Name.name, description: Faker::Lorem.paragraph,
        'created_at' => created_at, 'updated_at' => updated_at
      }
      Account.any_instance.stubs(:shared_ownership_enabled?).returns(false)
      post :create, construct_params({ version: 'channel' }, params)
      assert_response 201
      t = Helpdesk::Ticket.last
      match_json(ticket_pattern(params, t))
      match_json(ticket_pattern({}, t))
      assert (t.created_at - created_at).to_i.zero?
      assert (t.updated_at - updated_at).to_i.zero?
    ensure
      Account.any_instance.unstub(:shared_ownership_enabled?)
    end

    def test_update_with_jwt
      t = create_ticket
      t.update_attributes(created_at: Time.zone.now - 10.days, updated_at: Time.zone.now - 10.days)
      t = t.reload
      closed_at = Time.zone.now - 1.day
      params = {
        status: 5, priority: 2, source: 2, type: 'Question',
        closed_at: closed_at
      }
      Account.any_instance.stubs(:shared_ownership_enabled?).returns(false)
      update_params = construct_params({ id: t.display_id, version: 'channel' }, params)
      put :update, update_params
      assert_response 200
      t = Helpdesk::Ticket.last
      match_json(update_ticket_pattern(params, t))
      match_json(update_ticket_pattern({}, t))
      assert (t.closed_at - closed_at).to_i.zero?
    ensure
      Account.any_instance.unstub(:shared_ownership_enabled?)
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
    ensure
      Account.any_instance.unstub(:shared_ownership_enabled?)
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
    ensure
      Account.any_instance.unstub(:shared_ownership_enabled?)
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
    ensure
      Account.any_instance.unstub(:shared_ownership_enabled?)
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
      Account.current.instance_variable_set('@ticket_fields_from_cache', nil)
      post :create, construct_params({ version: 'private' }, params)
      assert_response 201
      t = Helpdesk::Ticket.last
      match_json(ticket_pattern(params, t))
      match_json(ticket_pattern({}, t))
      assert (t.closed_at - closed_at).to_i == 0
    ensure
      Account.any_instance.unstub(:shared_ownership_enabled?)
    end

    def test_facebook_post_ticket_create
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      fb_page_id = fetch_or_create_fb_page
      params = {
        requester_id: requester.id, status: 5, priority: 2, source: 6,
        subject: Faker::Name.name, description: Faker::Lorem.paragraph,
        source_additional_info: {
          facebook: { 
            post_id: "1075277095974458_1095516297283875", 
            msg_type: 'post', 
            page_id: fb_page_id, 
            can_comment: true, 
            post_type: 1 
          }
        }
      }
      Account.any_instance.stubs(:shared_ownership_enabled?).returns(false)
      post :create, construct_params({ version: 'private' }, params)
      assert_response 201
      t = Helpdesk::Ticket.last
      # To Do : use show ticket pattern to verify source additional info pattern 
      match_json(ticket_pattern(params, t))
    ensure
      Account.any_instance.unstub(:shared_ownership_enabled?)
      CustomRequestStore.store[:channel_api_request] = false
      @channel_v2_api = false
    end

    def test_facebook_dm_ticket_create
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      fb_page_id = fetch_or_create_fb_page
      params = {
        requester_id: requester.id, status: 5, priority: 2, source: 6,
        subject: Faker::Name.name, description: Faker::Lorem.paragraph,
        source_additional_info: { 
          facebook: { 
            post_id: "1075277095974458_1095516297283876", 
            msg_type: 'dm', 
            page_id: fb_page_id, 
            thread_id: "300175417269660::1943191972395357" 
          }
        }
      }
      Account.any_instance.stubs(:shared_ownership_enabled?).returns(false)
      post :create, construct_params({ version: 'private' }, params)
      assert_response 201
      t = Helpdesk::Ticket.last
      # To Do : use show ticket pattern to verify source additional info pattern 
      match_json(ticket_pattern(params, t))
    ensure
      Account.any_instance.unstub(:shared_ownership_enabled?)
      CustomRequestStore.store[:channel_api_request] = false
      @channel_v2_api = false
    end

    def test_twitter_mention_ticket_create
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      twitter_handle_id = get_twitter_handle.twitter_user_id
      params = {
        requester_id: requester.id, status: 5, priority: 2, source: 5,
        subject: Faker::Name.name, description: Faker::Lorem.paragraph,
        source_additional_info: {
          twitter: { 
            tweet_id: 12345,
            tweet_type: 'mention',
            support_handle_id: twitter_handle_id,
            stream_id: 3232
          }
        }
      }
      Account.any_instance.stubs(:shared_ownership_enabled?).returns(false)
      post :create, construct_params({ version: 'private' }, params)
      assert_response 201
      t = Helpdesk::Ticket.last
      match_json(show_ticket_pattern(params, t).except(:association_type))
    ensure
      Account.any_instance.unstub(:shared_ownership_enabled?)
      CustomRequestStore.store[:channel_api_request] = false
      @channel_v2_api = false
    end

    def test_twitter_dm_ticket_create
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      twitter_handle_id = get_twitter_handle.twitter_user_id
      params = {
        requester_id: requester.id, status: 5, priority: 2, source: 5,
        subject: Faker::Name.name, description: Faker::Lorem.paragraph,
        source_additional_info: {
          twitter: { 
            tweet_id: 12346,
            tweet_type: 'dm',
            support_handle_id: twitter_handle_id,
            stream_id: 3232
          }
        }
      }
      Account.any_instance.stubs(:shared_ownership_enabled?).returns(false)
      post :create, construct_params({ version: 'private' }, params)
      assert_response 201
      t = Helpdesk::Ticket.last
      match_json(show_ticket_pattern(params, t).except(:association_type))
    ensure
      Account.any_instance.unstub(:shared_ownership_enabled?)
      CustomRequestStore.store[:channel_api_request] = false
      @channel_v2_api = false
    end

    def test_twitter_ticket_create_with_invalid_handle_id
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      twitter_handle_id = Faker::Number.number(3).to_i
      params = {
        requester_id: requester.id, status: 5, priority: 2, source: 5,
        subject: Faker::Name.name, description: Faker::Lorem.paragraph,
        source_additional_info: {
          twitter: {
            tweet_id: 12346,
            tweet_type: 'dm',
            support_handle_id: twitter_handle_id,
            stream_id: 3232
          }
        }
      }
      Account.any_instance.stubs(:shared_ownership_enabled?).returns(false)
      post :create, construct_params({ version: 'private' }, params)
      assert_response 400
      pattern = validation_error_pattern(bad_request_error_pattern(:twitter_handle_id,
                                          :invalid_twitter_handle , code: 'invalid_value'))
      match_json(pattern)
    ensure
      Account.any_instance.unstub(:shared_ownership_enabled?)
      CustomRequestStore.store[:channel_api_request] = false
      @channel_v2_api = false
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
    ensure
      Account.any_instance.unstub(:shared_ownership_enabled?)
    end

    def test_update_with_duplicate_import_id
      ticket_with_import_id = create_ticket(import_id: 1004)
      ticket_to_update = create_ticket
      put :update, construct_params({ id: ticket_to_update.display_id, version: 'private' }, { import_id: ticket_with_import_id.import_id })
      assert_response 409
      assert_equal response.body, request_error_pattern(:duplicate_value).to_json
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
    ensure
      Account.any_instance.unstub(:shared_ownership_enabled?)
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
    ensure
      Account.any_instance.unstub(:shared_ownership_enabled?)
    end

    def test_create_with_duplicate_import_id
      ticket = create_ticket(import_id: 1003)
      params = {
        requester_id: requester.id, status: 2, priority: 2,
        subject: Faker::Name.name, description: Faker::Lorem.paragraph,
        import_id: ticket.import_id
      }
      post :create, construct_params({ version: 'private' }, params)
      assert_response 409
      assert_equal response.body, request_error_pattern(:duplicate_value).to_json
    end

    def test_index_without_permitted_tickets
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      Helpdesk::Ticket.update_all(responder_id: nil)
      get :index, controller_params(per_page: 50)
      assert_response 200
      response = parse_response @response.body
      assert_equal Helpdesk::Ticket.where(deleted: 0, spam: 0).created_in(Helpdesk::Ticket.created_in_last_month).count, response.size

      Agent.any_instance.stubs(:ticket_permission).returns(3)
      get :index, controller_params
      assert_response 200
      response = parse_response @response.body
      assert_equal 0, response.size

      expected = Helpdesk::Ticket.where(deleted: 0, spam: 0).created_in(Helpdesk::Ticket.created_in_last_month).update_all(responder_id: @agent.id)
      get :index, controller_params
      assert_response 200
      response = parse_response @response.body
      assert_equal expected, response.size
    ensure
      @channel_v2_api = false
      CustomRequestStore.store[:channel_api_request] = false
      Agent.any_instance.unstub(:ticket_permission)
    end

    def test_index_with_invalid_sort_params
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      get :index, controller_params(order_type: 'test', order_by: 'test')
      assert_response 400
      pattern = [bad_request_error_pattern('order_type', :not_included, list: 'asc,desc')]
      pattern << bad_request_error_pattern('order_by', :not_included, list: sort_field_options.join(','))
      match_json(pattern)
    ensure
      @channel_v2_api = false
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_index_sort_by_due_by_with_sla_disabled
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      Account.any_instance.stubs(:sla_management_enabled?).returns(false)
      get :index, controller_params(order_type: 'test', order_by: 'due_by')
      assert_response 400
      pattern = [bad_request_error_pattern('order_type', :not_included, list: 'asc,desc')]
      pattern << bad_request_error_pattern('order_by', :not_included, list: sort_field_options.join(','))
      match_json(pattern)
    ensure
      Account.any_instance.unstub(:sla_management_enabled?)
      @channel_v2_api = false
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_index_with_extra_params
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      hash = { filter_name: 'test', company_name: 'test' }
      get :index, controller_params(hash)
      assert_response 400
      pattern = []
      hash.keys.each { |key| pattern << bad_request_error_pattern(key, :invalid_field) }
      match_json pattern
    ensure
      @channel_v2_api = false
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_index_with_invalid_params
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      get :index, controller_params(company_id: 999, requester_id: '999', filter: 'x')
      pattern = [bad_request_error_pattern('filter', :not_included, list: 'new_and_my_open,watching,spam,deleted')]
      pattern << bad_request_error_pattern('company_id', :absent_in_db, resource: :company, attribute: :company_id)
      pattern << bad_request_error_pattern('requester_id', :absent_in_db, resource: :contact, attribute: :requester_id)
      assert_response 400
      match_json pattern
    ensure
      @channel_v2_api = false
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_index_with_invalid_email_in_params
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      get :index, controller_params(email: Faker::Internet.email)
      pattern = [bad_request_error_pattern('email', :absent_in_db, resource: :contact, attribute: :email)]
      assert_response 400
      match_json pattern
    ensure
      @channel_v2_api = false
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_index_with_invalid_params_type
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      get :index, controller_params(company_id: 'a', requester_id: 'b')
      pattern = [bad_request_error_pattern('company_id', :datatype_mismatch, expected_data_type: 'Positive Integer')]
      pattern << bad_request_error_pattern('requester_id', :datatype_mismatch, expected_data_type: 'Positive Integer')
      assert_response 400
      match_json pattern
    ensure
      @channel_v2_api = false
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_index_with_monitored_by
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      get :index, controller_params(filter: 'watching')
      assert_response 200
      response = parse_response @response.body
      assert_equal 0, response.count

      subscription = FactoryGirl.build(:subscription, account_id: @account.id,
                                                      ticket_id: Helpdesk::Ticket.first.id,
                                                      user_id: @agent.id)
      subscription.save
      get :index, controller_params(filter: 'watching')
      assert_response 200
      response = parse_response @response.body
      assert_equal 1, response.count
    ensure
      @channel_v2_api = false
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_index_with_new_and_my_open
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      Helpdesk::Ticket.update_all(status: 3)
      Helpdesk::Ticket.first.update_attributes(status: 2, responder_id: @agent.id,
                                               deleted: false, spam: false)
      get :index, controller_params(filter: 'new_and_my_open')
      assert_response 200
      response = parse_response @response.body
      assert_equal 1, response.size
    ensure
      @channel_v2_api = false
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_index_with_default_filter
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      Helpdesk::Ticket.update_all(created_at: 2.months.ago)
      Helpdesk::Ticket.first.update_attributes(created_at: 1.months.ago,
                                               deleted: false, spam: false)
      get :index, controller_params
      assert_response 200
      response = parse_response @response.body
      assert_equal 1, response.size
    ensure
      @channel_v2_api = false
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_index_with_default_filter_order_type
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      Helpdesk::Ticket.update_all(created_at: 2.months.ago)
      Helpdesk::Ticket.first.update_attributes(created_at: 1.months.ago,
                                               deleted: false, spam: false)
      get :index, controller_params(order_type: 'asc')
      assert_response 200
      response = parse_response @response.body
      assert_equal 1, response.size
    ensure
      @channel_v2_api = false
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_index_with_default_filter_order_by
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      @account.tickets.update_all(created_at: 2.months.ago)
      ticket = @account.tickets.first
      ticket.update_attributes(created_at: 1.months.ago,
                                                deleted: false, spam: false)
      get :index, controller_params(order_by: 'status')
      available_ticket = @account.tickets.where("id = #{ticket.id} and deleted = false and spam = false").first
      assert_response 200
      response = parse_response @response.body
      assert response.map { |res| res['ticket_id'] }.include?(available_ticket.id)
    ensure
      @channel_v2_api = false
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_index_with_spam
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      get :index, controller_params(filter: 'spam')
      assert_response 200
      response = parse_response @response.body
      assert_equal 0, response.size

      Helpdesk::Ticket.first.update_attributes(spam: true, created_at: 2.months.ago)
      get :index, controller_params(filter: 'spam')
      assert_response 200
      response = parse_response @response.body
      assert_equal 1, response.size
    ensure
      @channel_v2_api = false
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_index_with_spam_and_deleted
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      pattern = /SELECT  `helpdesk_tickets`.* FROM/
      from = 'WHERE '
      to = ' ORDER BY'
      query = trace_query_condition(pattern, from, to) { get :index, controller_params(filter: 'spam', updated_since: '2009-09-09') }
      assert_equal "`helpdesk_tickets`.`account_id` = 1 AND `helpdesk_tickets`.`deleted` = 0 AND `helpdesk_tickets`.`spam` = 1 AND (helpdesk_tickets.updated_at >= '2009-09-09 00:00:00')", query
      query = trace_query_condition(pattern, from, to) { get :index, controller_params(filter: 'deleted', updated_since: '2009-09-09') }
      assert_equal "`helpdesk_tickets`.`account_id` = 1 AND `helpdesk_tickets`.`deleted` = 1 AND `helpdesk_schema_less_tickets`.`boolean_tc02` = 0 AND (helpdesk_tickets.updated_at >= '2009-09-09 00:00:00')", query
      query = trace_query_condition(pattern, from, to) { get :index, controller_params(filter: 'spam') }
      assert_equal '`helpdesk_tickets`.`account_id` = 1 AND `helpdesk_tickets`.`deleted` = 0 AND `helpdesk_tickets`.`spam` = 1', query
      query = trace_query_condition(pattern, from, to) { get :index, controller_params(filter: 'spam', requester_id: 1) }
      assert_equal '`helpdesk_tickets`.`account_id` = 1 AND `helpdesk_tickets`.`deleted` = 0 AND `helpdesk_tickets`.`requester_id` = 1 AND `helpdesk_tickets`.`spam` = 1', query
      query = trace_query_condition(pattern, from, to) { get :index, controller_params }
      assert_match(/`helpdesk_tickets`.`account_id` = 1 AND `helpdesk_tickets`\.`deleted` = 0 AND `helpdesk_tickets`\.`spam` = 0 AND \(helpdesk_tickets.created_at > '.*'\)$/, query)
      query = trace_query_condition(pattern, from, to) { get :index, controller_params(filter: 'spam', company_id: 1) }
      assert_equal '`helpdesk_tickets`.`account_id` = 1 AND `helpdesk_tickets`.`deleted` = 0 AND `helpdesk_tickets`.`owner_id` = 1 AND `helpdesk_tickets`.`spam` = 1', query
    ensure
      @channel_v2_api = false
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_index_with_deleted
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      TicketDecorator.any_instance.stubs(:private_api?).returns(true)
      tkts = Helpdesk::Ticket.select { |x| x.deleted && !x.schema_less_ticket.boolean_tc02 }
      t = ticket
      t.update_column(:deleted, true)
      t.update_column(:spam, true)
      t.update_column(:created_at, 2.months.ago)
      tkts << t.reload
      get :index, controller_params(filter: 'deleted')
      pattern = []
      tkts.each { |tkt| pattern << index_deleted_ticket_pattern(tkt) }
      match_json(pattern)

      t.update_column(:deleted, false)
      t.update_column(:spam, false)
      assert_response 200
    ensure
      unstub_requirements_for_stats
    end

    def test_index_with_requester_filter
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      Helpdesk::Ticket.update_all(requester_id: User.first.id)
      ticket = create_ticket(requester_id: User.last.id)
      ticket.update_column(:created_at, 2.months.ago)
      get :index, controller_params(requester_id: "#{User.last.id}")
      assert_response 200
      response = parse_response @response.body
      assert_equal 1, response.count
      set_wrap_params
    ensure
      @channel_v2_api = false
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_index_with_filter_and_requester_email
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      user = add_new_user(@account)

      get :index, controller_params(filter: 'new_and_my_open', email: user.email)
      assert_response 200
      response = parse_response @response.body
      assert_equal 0, response.count

      ticket = @account.tickets.where(deleted: 0, spam: 0).first || create_ticket(requester_id: user.id)
      ticket.update_attributes(requester_id: user.id, status: 2)
      get :index, controller_params(filter: 'new_and_my_open', email: user.email)
      assert_response 200
      response = parse_response @response.body
      assert_equal 1, response.count
    ensure
      @channel_v2_api = false
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_index_with_company
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      TicketDecorator.any_instance.stubs(:private_api?).returns(true)
      company = create_company
      user = add_new_user(@account)
      sidekiq_inline {
        user.company_id = company.id
        user.save!
      }
      ticket = create_ticket(requester_id: user.id)
      get :index, controller_params(company_id: "#{company.id}")
      assert_response 200

      tkts = Helpdesk::Ticket.where(owner_id: company.id)
      pattern = tkts.map { |tkt| index_ticket_pattern(tkt) }
      match_json(pattern)
    ensure
      @channel_v2_api = false
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_index_with_filter_and_requester
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      user1 = add_new_user(@account)
      user2 = add_new_user(@account)
      ticket = @account.tickets.where(deleted: 0, spam: 0).first || create_ticket(requester_id: user1.id)
      Helpdesk::Ticket.update_all(requester_id: user1.id)
      get :index, controller_params(filter: 'new_and_my_open', requester_id: "#{user2.id}")
      assert_response 200
      response = parse_response @response.body
      assert_equal 0, response.count

      ticket.update_attributes(requester_id: user2.id, status: 2)
      get :index, controller_params(filter: 'new_and_my_open', requester_id: "#{user2.id}")
      assert_response 200
      response = parse_response @response.body
      assert_equal 1, response.count
    ensure
      @channel_v2_api = false
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_index_with_filter_and_company
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      Helpdesk::Ticket.update_all(status: 3)
      user = get_user_with_default_company
      user_id = user.id
      company_id = user.company.id
      Helpdesk::Ticket.where(deleted: 0, spam: 0).update_all(
        requester_id: nil, owner_id: nil
      )

      get :index, controller_params(filter: 'new_and_my_open', company_id: "#{company_id}")
      assert_response 200
      response = parse_response @response.body
      assert_equal 0, response.count

      tkt = Helpdesk::Ticket.first
      tkt.update_attributes(
        status: 2, requester_id: user_id,
        owner_id: company_id, responder_id: nil
      )
      get :index, controller_params(
        filter: 'new_and_my_open',
        company_id: "#{company_id}"
      )
      assert_response 200
      response = parse_response @response.body
      assert_equal 1, response.count
    ensure
      @channel_v2_api = false
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_index_with_company_and_requester
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      company = Company.first
      user1 = User.first
      user2 = User.first(2).last
      sidekiq_inline { user1.update_attributes(company_id: company.id) }
      user1.reload

      expected_size = @account.tickets.where(deleted: 0, spam: 0, requester_id: user1.id, owner_id: company.id).count
      get :index, controller_params(company_id: company.id, requester_id: "#{user1.id}")
      assert_response 200
      response = parse_response @response.body
      assert_equal expected_size, response.size

      sidekiq_inline { user2.update_attributes(company_id: nil) }
      get :index, controller_params(company_id: company.id, requester_id: "#{user2.id}")
      assert_response 200
      response = parse_response @response.body
      assert_equal 0, response.size
    ensure
      @channel_v2_api = false
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_index_with_requester_filter_company
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      remove_wrap_params
      user = get_user_with_default_company
      user_id = user.id
      company = user.company
      new_company = create_company
      add_new_user(@account, customer_id: new_company.id)
      Helpdesk::Ticket.where(deleted: 0, spam: 0).update_all(requester_id: new_company.users.map(&:id).first)
      get :index, controller_params(company_id: company.id,
                                    requester_id: "#{User.first.id}", filter: 'new_and_my_open')
      assert_response 200
      response = parse_response @response.body
      assert_equal 0, response.size

      Helpdesk::Ticket.where(deleted: 0, spam: 0).first.update_attributes(requester_id: user_id,
                                                                          status: 2, responder_id: nil)
      get :index, controller_params(company_id: company.id,
                                    requester_id: "#{user_id}", filter: 'new_and_my_open')
      assert_response 200
      response = parse_response @response.body
      assert_equal 1, response.size
    ensure
      @channel_v2_api = false
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_index_with_requester_nil
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      ticket = create_ticket
      ticket.requester.destroy
      get :index, controller_params(include: 'requester')
      assert_response 200
      requester_hash = JSON.parse(response.body).select { |x| x['id'] == ticket.display_id }.first['requester']
      ticket.destroy
      assert requester_hash.nil?
    ensure
      @channel_v2_api = false
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_index_with_dates
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      TicketDecorator.any_instance.stubs(:private_api?).returns(true)
      count = Account.current.tickets.where("updated_at >= ?", Time.zone.now.utc.iso8601).count
      get :index, controller_params(updated_since: Time.zone.now.utc.iso8601)
      assert_response 200
      response = parse_response @response.body
      assert_equal count, response.size

      tkt = Helpdesk::Ticket.first
      tkt.update_column(:created_at, 1.days.from_now)
      count = Account.current.tickets.where("updated_at >= ?", Time.zone.now.utc.iso8601).count
      get :index, controller_params(updated_since: Time.zone.now.utc.iso8601)
      assert_response 200
      response = parse_response @response.body
      assert_equal count, response.size

      tkt.update_column(:updated_at, 1.days.from_now)
      count = Account.current.tickets.where("updated_at >= ?", Time.zone.now.utc.iso8601).count
      get :index, controller_params(updated_since: Time.zone.now.utc.iso8601)
      assert_response 200
      response = parse_response @response.body
      assert_equal count, response.size
    ensure
      unstub_requirements_for_stats
    end

    def test_index_with_time_zone
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      tkt = Helpdesk::Ticket.where(deleted: false, spam: false).first
      old_time_zone = Time.zone.name
      Time.zone = 'Chennai'
      get :index, controller_params(updated_since: tkt.updated_at.iso8601)
      assert_response 200
      response = parse_response @response.body
      assert response.size > 0
      assert response.map { |item| item['ticket_id'] }
      Time.zone = old_time_zone
    ensure
      @channel_v2_api = false
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_index_with_stats
      TicketDecorator.any_instance.stubs(:private_api?).returns(false)
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      get :index, controller_params(include: 'stats')
      assert_response 200
      response = parse_response @response.body
      tkts =  Helpdesk::Ticket.where(deleted: 0, spam: 0)
                              .created_in(Helpdesk::Ticket.created_in_last_month)
                              .order('created_at DESC')
                              .limit(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page])
      assert_equal tkts.count, response.size
      param_object = OpenStruct.new
      pattern = tkts.map do |tkt|
        index_ticket_pattern_with_associations(tkt, param_object)
      end
      match_json(pattern)
    ensure
      @channel_v2_api = false
      TicketDecorator.any_instance.unstub(:private_api?)
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_index_with_empty_include
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      get :index, controller_params(include: '')
      assert_response 400
      match_json([bad_request_error_pattern(
        'include', :not_included,
        list: 'requester, stats, company, description')]
      )
    ensure
      @channel_v2_api = false
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_index_with_wrong_type_include
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      get :index, controller_params(include: ['test'])
      assert_response 400
      match_json([bad_request_error_pattern('include', :datatype_mismatch, expected_data_type: 'String', prepend_msg: :input_received, given_data_type: 'Array')])
    ensure
      @channel_v2_api = false
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_index_with_invalid_param_value
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      get :index, controller_params(include: 'test')
      assert_response 400
      match_json([bad_request_error_pattern(
        'include', :not_included,
        list: 'requester, stats, company, description')]
      )
    ensure
      @channel_v2_api = false
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_index_with_requester
      TicketDecorator.any_instance.stubs(:private_api?).returns(false)
      get :index, controller_params(include: 'requester')
      assert_response 200
      response = parse_response @response.body
      tkts =  Helpdesk::Ticket.where(deleted: 0, spam: 0)
                              .created_in(Helpdesk::Ticket.created_in_last_month)
                              .order('created_at DESC')
                              .limit(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page])
      assert_equal tkts.count, response.size
      param_object = OpenStruct.new(requester: true)
      pattern = tkts.map do |tkt|
        index_ticket_pattern_with_associations(tkt, param_object)
      end
      match_json(pattern)
    ensure
      TicketDecorator.any_instance.unstub(:private_api?)
    end

    def test_index_with_company_side_load
      TicketDecorator.any_instance.stubs(:private_api?).returns(false)
      tkts =  Helpdesk::Ticket.where(deleted: 0, spam: 0)
                              .created_in(Helpdesk::Ticket.created_in_last_month)
                              .order('created_at DESC')
                              .limit(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page])
      get :index, controller_params(include: 'company')
      assert_response 200
      response = parse_response @response.body
      assert_equal tkts.count, response.size
      param_object = OpenStruct.new(:company => true)
      pattern = tkts.map do |tkt|
        index_ticket_pattern_with_associations(tkt, param_object)
      end
      match_json(pattern)
    ensure
      TicketDecorator.any_instance.unstub(:private_api?)
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
      # Random test case failure - this "if" block is just to avoid failure on every monday between '00:00' and '08:00'
      if Time.zone.now.to_date.monday? && response.status != 201 && Time.zone.now.to_time.utc.between?((started_bhr_time - 8.hours), started_bhr_time)
        pattern = []
        [:created_at, :updated_at].each { |key| pattern << bad_request_error_pattern(key, :start_time_lt_now) }
        p "test_sla_calculation_if_created_at_current_time :: pattern :: #{pattern.inspect}"
        match_json(pattern)
        return
      end
      assert_response 201
      t = Helpdesk::Ticket.last
      match_json(ticket_pattern(params, t))
      match_json(ticket_pattern({}, t))
      created_at = Time.parse created_at
      updated_at = Time.parse updated_at
      assert (t.created_at - created_at).to_i.zero?
      assert (t.updated_at - updated_at).to_i.zero?
      assert t.due_by - t.created_at == 1.day, "Expected due_by => #{t.due_by.inspect} to be 1 day ahead of created time => #{t.created_at.inspect}"
      assert t.frDueBy - t.created_at == 8.hour, "Expected frDueBy => #{t.frDueBy.inspect} to be 8 hours ahead of created time => #{t.created_at.inspect}"
    ensure
      BusinessCalendar.any_instance.unstub(:holidays)
      Account.any_instance.unstub(:shared_ownership_enabled?)
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
      assert t.due_by - t.created_at == 1.day, "Expected due_by => #{t.due_by.inspect} to be 1 day ahead of created time => #{t.created_at.inspect}"
      assert t.frDueBy - t.created_at == 8.hour, "Expected frDueBy => #{t.frDueBy.inspect} to be 8 hours ahead of created time => #{t.created_at.inspect}"
    ensure
      BusinessCalendar.any_instance.unstub(:holidays)
      Account.any_instance.unstub(:shared_ownership_enabled?)
    end

    def test_sla_calculation_if_created_at_is_greater_than_1month
      BusinessCalendar.any_instance.stubs(:holidays).returns([])
      current_time = Time.now.monday
      started_bhr_time = Time.gm(current_time.year, current_time.month, current_time.day, 8) # fix date so to calculate sla correctly
      created_at = updated_at = (started_bhr_time - 2.month).iso8601
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
      assert t.created_at + 1.month == t.due_by, "Expected due_by => #{t.due_by.inspect} should be 1 month after created time => #{t.created_at.inspect}"
      assert t.created_at + 1.month == t.frDueBy, "Expected frDueBy => #{t.frDueBy.inspect} should be 1 month after created time => #{t.created_at.inspect}"
    ensure
      BusinessCalendar.any_instance.unstub(:holidays)
      Account.any_instance.unstub(:shared_ownership_enabled?)
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
    ensure
      Account.any_instance.unstub(:shared_ownership_enabled?)
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
    ensure
      Account.any_instance.unstub(:shared_ownership_enabled?)
    end

    def test_index_channel_api_with_read_scope
      TicketDecorator.any_instance.stubs(:private_api?).returns(false)
      CustomRequestStore.store[:channel_api_request] = true
      Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
      @channel_v2_api = true
      agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
      group = create_group_with_agents(@account, agent_list: [agent.id])
      agent_group = agent.agent_groups.where(group_id: group.id).first
      agent_group.write_access = false
      agent_group.save!
      agent.make_current
      ticket1 = create_ticket({}, group)
      login_as(agent)
      get :index, controller_params(version: 'channel')
      assert_equal JSON.parse(@response.body)[0]['ticket_id'], ticket1.id
      assert_response 200
    ensure
      @channel_v2_api = false
      Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
      TicketDecorator.any_instance.unstub(:private_api?)
      CustomRequestStore.store[:channel_api_request] = false
      ticket1.destroy if ticket1.present?
      agent.destroy if agent.present?
    end

    def test_index_channel_api_with_internal_group_read_scope
      TicketDecorator.any_instance.stubs(:private_api?).returns(false)
      CustomRequestStore.store[:channel_api_request] = true
      Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
      @channel_v2_api = true
      @account.add_feature :shared_ownership
      initialize_internal_agent_with_default_internal_group(2)
      agent_group = @internal_agent.all_agent_groups.where(group_id: @internal_group.id).first
      ticket1 = create_ticket({ status: @status.status_id, internal_agent_id: @internal_agent.id,
                                responder_id: @responding_agent.id }, nil, @internal_group)
      ticket2 = create_ticket({ status: @status.status_id, internal_agent_id: @internal_agent.id,
                                responder_id: @responding_agent.id }, nil, @internal_group)
      agent_group.write_access = false
      agent_group.save!
      @internal_agent.make_current
      login_as(@internal_agent)
      get :index, controller_params(version: 'channel')
      assert_response 200
      response = parse_response @response.body
      response_ticket_ids = response.map { |ticket| ticket['id'] }
      assert_equal (response_ticket_ids.include? ticket1.display_id), true
      agent_group.write_access = true
      agent_group.save!
    ensure
      @channel_v2_api = false
      Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
      TicketDecorator.any_instance.unstub(:private_api?)
      CustomRequestStore.store[:channel_api_request] = false
      ticket1.destroy if ticket1.present?
      ticket2.destroy if ticket2.present?
      @responding_agent.destroy if @responding_agent.present?
      @internal_agent.destroy if @internal_agent.present?
    end

    def test_ticket_create_with_whatsapp_source_and_feature_enabled
      Account.current.launch(:whatsapp_ticket_source)
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      params = {
        name: Faker::Name.name,
        phone: Faker::PhoneNumber.phone_number,
        subject: Faker::Lorem.words(10).join(' '),
        description: Faker::Lorem.paragraph,
        priority: 1,
        status: 2,
        source: 13
      }
      Account.any_instance.stubs(:shared_ownership_enabled?).returns(false)
      post :create, construct_params({ version: 'private' }, params)
      assert_response 201
      response = JSON.parse @response.body
      t = Account.current.tickets.where(display_id: response['id']).first
      match_json(ticket_pattern(params, t))
    ensure
      Account.current.rollback(:whatsapp_ticket_source)
      Account.any_instance.unstub(:shared_ownership_enabled?)
      CustomRequestStore.store[:channel_api_request] = false
      @channel_v2_api = false
    end

    def test_ticket_create_with_whatsapp_source_and_feature_disabled
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      params = {
        name: Faker::Name.name,
        phone: Faker::PhoneNumber.phone_number,
        subject: Faker::Lorem.words(10).join(' '),
        description: Faker::Lorem.paragraph,
        priority: 1,
        status: 2,
        source: 13
      }
      Account.any_instance.stubs(:shared_ownership_enabled?).returns(false)
      post :create, construct_params({ version: 'private' }, params)
      assert_response 400
      pattern = validation_error_pattern(bad_request_error_pattern('source', :not_included, list: api_ticket_sources.join(',')))
      match_json(pattern)
    ensure
      CustomRequestStore.store[:channel_api_request] = false
      @channel_v2_api = false
    end

    def test_sync_tickets_auth_failure_403
      post :sync, construct_params({ version: 'channel' }, meta: 'abc')
      assert_response 403
    end

    def test_tickets_resync_with_invalid_source
      invalid_source = 'silkroad'
      remove_others_redis_key(resync_rate_limiter_key(invalid_source))
      set_jwt_auth_header(invalid_source)
      args = { meta: { meta_id: 'abc' }, display_ids: [1, 2] }
      post :sync, construct_params({ version: 'channel' }, args)
      assert_response 403
    end

    def test_tickets_resync_with_worker_limit_reached
      set_jwt_auth_header(CHANNEL_SOURCE)
      set_others_redis_key_if_not_present(resync_rate_limiter_key(CHANNEL_SOURCE), 5)
      args = { meta: { meta_id: 'abc' }, display_ids: [1, 2] }
      post :sync, construct_params({ version: 'channel' }, args)
      assert_response 429
    ensure
      remove_others_redis_key(resync_rate_limiter_key(CHANNEL_SOURCE))
    end

    def test_tickets_resync_success
      set_jwt_auth_header(CHANNEL_SOURCE)
      job_id = SecureRandom.hex
      request.stubs(:uuid).returns(job_id)
      remove_others_redis_key(resync_rate_limiter_key(CHANNEL_SOURCE))
      args = { meta: { meta_id: 'abc' }, display_ids: [1, 2] }
      CentralPublish::ResyncWorker.jobs.clear
      post :sync, construct_params({ version: 'channel' }, args)
      assert_equal 1, CentralPublish::ResyncWorker.jobs.size
      assert_response 202
      match_json(tickets_sync_pattern(job_id))
    ensure
      request.unstub(:uuid)
    end

    def test_tickets_resync_success_with_date_filters
      set_jwt_auth_header(CHANNEL_SOURCE)
      job_id = SecureRandom.hex
      request.stubs(:uuid).returns(job_id)
      remove_others_redis_key(resync_rate_limiter_key(CHANNEL_SOURCE))
      start_date = Time.zone.now - 3.days
      end_date = start_date + 2.days
      CentralPublish::ResyncWorker.jobs.clear
      args = { meta: { meta_id: 'abc' }, created_at: date_time_range(start_date, end_date),
               updated_at: date_time_range(start_date, end_date), resolved_at: date_time_range(start_date, end_date),
               closed_at: date_time_range(start_date, end_date) }
      post :sync, construct_params({ version: 'channel' }, args)
      assert_equal 1, CentralPublish::ResyncWorker.jobs.size
      assert_response 202
      match_json(tickets_sync_pattern(job_id))
    ensure
      request.unstub(:uuid)
    end

    def test_tickets_resync_with_no_filters
      set_jwt_auth_header(CHANNEL_SOURCE)
      remove_others_redis_key(resync_rate_limiter_key(CHANNEL_SOURCE))
      args = { meta: { meta_id: 'abc' } }
      post :sync, construct_params({ version: 'channel' }, args)
      assert_response 400
      pattern = validation_error_pattern(bad_request_error_pattern(:require_filter_params, 'Anyone of the following filter attributes is mandatory: display_ids, created_at, updated_at, resolved_at, closed_at.', code: 'missing_field'))
      match_json(pattern)
    end

    def test_tickets_resync_with_invalid_date_range
      set_jwt_auth_header(CHANNEL_SOURCE)
      remove_others_redis_key(resync_rate_limiter_key(CHANNEL_SOURCE))
      start_date = Time.zone.now - 3.days
      end_date = start_date - 2.days
      args = { meta: { meta_id: 'abc' }, created_at: date_time_range(start_date, end_date) }
      post :sync, construct_params({ version: 'channel' }, args)
      assert_response 400
      pattern = validation_error_pattern(bad_request_error_pattern(:created_at, 'Invalid date time range, end time should be greater or equal to the start time.', code: 'invalid_value'))
      match_json(pattern)
    end

    def test_tickets_resync_with_invalid_date_fields
      set_jwt_auth_header(CHANNEL_SOURCE)
      remove_others_redis_key(resync_rate_limiter_key(CHANNEL_SOURCE))
      start_date = Time.zone.now - 3.days
      end_date = 'nil'
      args = { meta: { meta_id: 'abc' }, created_at: date_time_range(start_date, end_date) }
      post :sync, construct_params({ version: 'channel' }, args)
      assert_response 400
      pattern = validation_error_pattern(bad_request_error_pattern(:created_at, 'Value set is of type String.It should be a/an DateTime', code: 'datatype_mismatch'))
      match_json(pattern)
    end

    def test_tickets_resync_with_greater_date_range
      set_jwt_auth_header(CHANNEL_SOURCE)
      remove_others_redis_key(resync_rate_limiter_key(CHANNEL_SOURCE))
      start_date = Time.zone.now - 3.days
      end_date = start_date + 3.days
      args = { meta: { meta_id: 'abc' }, created_at: date_time_range(start_date, end_date) }
      post :sync, construct_params({ version: 'channel' }, args)
      assert_response 400
      pattern = validation_error_pattern(bad_request_error_pattern(:created_at, 'Datetime range can only be a maximum of 2 days', code: 'invalid_value'))
      match_json(pattern)
    end

    def test_tickets_resync_with_invalid_array_fields
      set_jwt_auth_header(CHANNEL_SOURCE)
      remove_others_redis_key(resync_rate_limiter_key(CHANNEL_SOURCE))
      args = { meta: { meta_id: 'abc' }, display_ids: nil }
      post :sync, construct_params({ version: 'channel' }, args)
      assert_response 400
      pattern = validation_error_pattern(bad_request_error_pattern(:display_ids, 'Value set is of type Null.It should be a/an Array', code: 'datatype_mismatch'))
      match_json(pattern)
    end

    def test_tickets_resync_with_invalid_meta
      set_jwt_auth_header(CHANNEL_SOURCE)
      remove_others_redis_key(resync_rate_limiter_key(CHANNEL_SOURCE))
      args = { meta: nil, display_ids: [1] }
      post :sync, construct_params({ version: 'channel' }, args)
      assert_response 400
      pattern = validation_error_pattern(bad_request_error_pattern(:meta, "can't be blank", code: 'invalid_value'))
      match_json(pattern)
    end

    def test_tickets_resync_with_invalid_primary_key_offset
      set_jwt_auth_header(CHANNEL_SOURCE)
      remove_others_redis_key(resync_rate_limiter_key(CHANNEL_SOURCE))
      args = { meta: { meta_id: 'abc' }, display_ids: [1, 2], primary_key_offset: 'id' }
      post :sync, construct_params({ version: 'channel' }, args)
      assert_response 400
      pattern = validation_error_pattern(bad_request_error_pattern(:primary_key_offset, 'Value set is of type String.It should be a/an Positive Integer', code: 'datatype_mismatch'))
      match_json(pattern)
    end

    def test_unauthorized_status_code_on_invalid_channel_source
      params = {
        requester_id: requester.id, status: 2, priority: 2,
        subject: Faker::Name.name, description: Faker::Lorem.paragraph
      }
      set_jwt_auth_header('silkroad')
      @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
      post :create, construct_params({ version: 'channel' }, params)
      assert_response 401
    ensure
      @controller.unstub(:api_current_user)
    end

    def test_unauthorized_status_code_on_invalid_token_payload
      params = {
        requester_id: requester.id, status: 2, priority: 2,
        subject: Faker::Name.name, description: Faker::Lorem.paragraph
      }
      token = generate_custom_jwt_token('multiplexer').split('.')
      token[1] = "#{token[1]}#{Faker::Lorem.word}"
      request.env['X-Channel-Auth'] = token.join('.')
      post :create, construct_params({ version: 'channel' }, params)
      assert_response 401
    end

    private

      def date_time_range(start_date, end_date)
        { start: start_date.to_s, end: end_date.to_s }
      end
  end
end
