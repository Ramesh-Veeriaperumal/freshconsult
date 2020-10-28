require_relative '../../../test_helper'

module Channel
  module Bot
    class TicketsControllerTest < ActionController::TestCase
      include ApiTicketsTestHelper
      include BotTicketHelper
      include ProductsHelper
      include JweTestHelper

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

      SUPPORT_BOT = 'frankbot'.freeze

      def setup
        super
        before_all
      end

      @before_all_run = false

      def before_all
        @account.sections.map(&:destroy)
        return if @before_all_run
        @account.ticket_fields.custom_fields.each(&:destroy)
        ticket_status = Helpdesk::TicketStatus.where(status_id: 2).first
        ticket_status.stop_sla_timer = false
        ticket_status.save
        ticket_fields = []
        @custom_field_names = []
        ticket_fields << create_dependent_custom_field(%w[test_custom_country test_custom_state test_custom_city])
        ticket_fields << create_custom_field_dropdown('test_custom_dropdown', ['Get Smart', 'Pursuit of Happiness', 'Armaggedon'])
        CUSTOM_FIELDS.each do |custom_field|
          next if %w[dropdown country state city].include?(custom_field)
          ticket_fields << create_custom_field("test_custom_#{custom_field}", custom_field)
          @custom_field_names << ticket_fields.last.name
        end
        portal_id = @account.main_portal.id
        @bot = Account.current.bots.where(portal_id: portal_id).first || create_bot(portal_id)
        @account_id = Account.current.id
        Account.reset_current_account
        Account.find(@account_id).make_current

        @before_all_run = true
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
                        priority: 2, status: 2, type: 'Problem', responder_id: agent_id, tags: tags,
                        due_by: 14.days.since.iso8601, fr_due_by: 1.day.since.iso8601, group_id: @create_group.id, bot_external_id: @bot.external_id, query_id: '3b04a7cd-2cb8-4d71-9aa9-1ac6dfce1c2b', conversation_id: 'c3aab027-6aa8-4383-9b85-82ed47dc366b'}
        params_hash
      end

      def test_create_without_authentication
        enable_bot_feature do
          params = { email: Faker::Internet.email, bot_external_id: @bot.external_id, query_id: '3b04a7cd-2cb8-4d71-9aa9-1ac6dfce1c2b', conversation_id: 'c3aab027-6aa8-4383-9b85-82ed47dc366b' }
          post :create, construct_params({version: 'channel'}, params)
          assert_response 401
          match_json(request_error_pattern(:invalid_credentials))
        end
      end

      def test_create_without_default_fields_required_except_requester_and_bot_data
        skip('Failure because of memcache issue. Raghav will fix it #FD-33639')
        enable_bot_feature do
          set_jwe_auth_header(SUPPORT_BOT)
          params = { email: Faker::Internet.email, bot_external_id: @bot.external_id, query_id: '3b04a7cd-2cb8-4d71-9aa9-1ac6dfce1c2b', conversation_id: 'c3aab027-6aa8-4383-9b85-82ed47dc366b' }
          post :create, construct_params({version: 'channel'}, params)
          ticket = @account.tickets.last
          match_json(ticket_pattern(params, ticket))
          match_json(ticket_pattern({}, ticket))
          result = parse_response(@response.body)
          response_headers = response.headers
          assert_equal true, response_headers.include?('Location')
          assert_equal "http://#{@request.host}/api/v2/tickets/#{result['id']}", response_headers['Location']
          assert_response 201
          validate_bot_ticket_data ticket, params[:bot_external_id], params[:query_id], params[:conversation_id]
        end
      end

      def test_create_without_default_fields_required
        enable_bot_feature do
          set_jwe_auth_header(SUPPORT_BOT)
          post :create, construct_params({version: 'channel'}, {})
          assert_response 400
          match_json([bad_request_error_pattern('requester_id', :fill_a_mandatory_field, field_names: 'requester_id, phone, email, twitter_id, facebook_id'),
                      bad_request_error_pattern('bot_external_id', :datatype_mismatch, code: :missing_field, expected_data_type: String),
                      bad_request_error_pattern('query_id', :datatype_mismatch, code: :missing_field, expected_data_type: String),
                      bad_request_error_pattern('conversation_id', :datatype_mismatch, code: :missing_field, expected_data_type: String)])
        end
      end

      def test_create_with_all_default_fields_required_invalid
        enable_bot_feature do
          set_jwe_auth_header(SUPPORT_BOT)
          default_non_required_fields = Helpdesk::TicketField.where(required: false, default: 1)
          toggle_required_attribute(default_non_required_fields)
          params_hash = {
            subject: 1,
            description: 1,
            group_id: 'z',
            product_id: 'y',
            responder_id: 'x',
            status: 999,
            priority: 999,
            type: 'Test',
            email: Faker::Internet.email,
            bot_external_id: 12,
            query_id: 12,
            conversation_id: 12
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
                      bad_request_error_pattern('type', :not_included, list: ticket_type_list),
                      bad_request_error_pattern('bot_external_id', :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Integer'),
                      bad_request_error_pattern('query_id', :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Integer'),
                      bad_request_error_pattern('conversation_id', :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Integer')])
          assert_response 400
          toggle_required_attribute(default_non_required_fields)
        end
      end

      def test_create_without_custom_fields_required
        skip('Failure because of memcache issue. Raghav will fix it #FD-33639')
        enable_bot_feature do
          set_jwe_auth_header(SUPPORT_BOT)
          params_hash = ticket_params_hash
          custom_fields = Helpdesk::TicketField.where(name: [@custom_field_names])
          toggle_required_attribute(custom_fields)
          post :create, construct_params({version: 'channel'}, params_hash)
          toggle_required_attribute(custom_fields)
          ticket = @account.tickets.last
          match_json(ticket_pattern(params_hash, ticket))
          match_json(ticket_pattern({}, ticket))
          result = parse_response(@response.body)
          response_headers = response.headers
          assert_equal true, response_headers.include?('Location')
          assert_equal "http://#{@request.host}/api/v2/tickets/#{result['id']}", response_headers['Location']
          assert_response 201
          validate_bot_ticket_data ticket, params_hash[:bot_external_id], params_hash[:query_id], params_hash[:conversation_id]
        end
      end

      def test_create_with_custom_fields_required_invalid
        skip('Failure because of memcache issue. Raghav will fix it #FD-33639')
        enable_bot_feature do
          set_jwe_auth_header(SUPPORT_BOT)
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
      end

      def test_create_without_support_bot_feature
        set_jwe_auth_header(SUPPORT_BOT)
        params = { email: Faker::Internet.email, bot_external_id: @bot.external_id, query_id: '3b04a7cd-2cb8-4d71-9aa9-1ac6dfce1c2b', conversation_id: 'c3aab027-6aa8-4383-9b85-82ed47dc366b' }
        post :create, construct_params({version: 'channel'}, params)
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: 'Support Bot'))
      end

      def test_create_without_source
        enable_bot_feature do
          set_jwe_auth_header(SUPPORT_BOT)
          params = { email: Faker::Internet.email, bot_external_id: @bot.external_id, query_id: '3b04a7cd-2cb8-4d71-9aa9-1ac6dfce1c2b', conversation_id: 'c3aab027-6aa8-4383-9b85-82ed47dc366b' }
          post :create, construct_params({version: 'channel'}, params)
          ticket = @account.tickets.last
          assert_response 201
          validate_bot_ticket_data ticket, params[:bot_external_id], params[:query_id], params[:conversation_id]
          assert_equal Helpdesk::Source::BOT, ticket.source
        end
      end

      def test_create_for_product_portal_bot
        enable_bot_feature do
          set_jwe_auth_header(SUPPORT_BOT)
          product = create_product(portal_url: Faker::Internet.domain_name)
          portal_id = product.portal.id
          bot = create_bot(portal_id)
          params = { email: Faker::Internet.email, bot_external_id: bot.external_id, query_id: '3b04a7cd-2cb8-4d71-9aa9-1ac6dfce1c2b', conversation_id: 'c3aab027-6aa8-4383-9b85-82ed47dc366b' }
          post :create, construct_params({version: 'channel'}, params)
          ticket = @account.tickets.last
          assert_response 201
          validate_bot_ticket_data ticket, params[:bot_external_id], params[:query_id], params[:conversation_id]
          assert_equal product.id, ticket.product_id
          assert_equal Helpdesk::Source::BOT, ticket.source
        end
      end

      def test_create_with_source
        enable_bot_feature do
          set_jwe_auth_header(SUPPORT_BOT)
          params = { email: Faker::Internet.email, bot_external_id: @bot.external_id, query_id: '3b04a7cd-2cb8-4d71-9aa9-1ac6dfce1c2b', conversation_id: 'c3aab027-6aa8-4383-9b85-82ed47dc366b', source: Helpdesk::Source::BOT }
          post :create, construct_params({version: 'channel'}, params)
          assert_response 400
          match_json([bad_request_error_pattern('source', :invalid_field)])
        end
      end

      def test_create_with_invalid_bot_id
        enable_bot_feature do
          set_jwe_auth_header(SUPPORT_BOT)
          params = { email: Faker::Internet.email, bot_external_id: '1', query_id: '3b04a7cd-2cb8-4d71-9aa9-1ac6dfce1c2b', conversation_id: 'c3aab027-6aa8-4383-9b85-82ed47dc366b' }
          post :create, construct_params({version: 'channel'}, params)
          assert_response 400
          match_json(request_error_pattern(:invalid_bot, id: '1'))
        end
      end
    end
  end
end
