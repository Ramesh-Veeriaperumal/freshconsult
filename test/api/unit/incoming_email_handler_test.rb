require_relative '../../api/unit_test_helper'
require_relative '../../core/helpers/tickets_test_helper'
module Helpdesk
  module Email
    class IncomingEmailHandlerTest < ActionView::TestCase
      include TicketsTestHelper

      def setup
        Account.stubs(:current).returns(Account.first)
        Account.stubs(:find_by_full_domain).returns(Account.first)
        shard = ShardMapping.first
        shard.status = 200 unless shard.status == 200
        shard.save
        @from_email = Faker::Internet.email
        @to_email = Faker::Internet.email
      end

      def teardown
        super
        Account.unstub(:current)
        Account.unstub(:find_by_full_domain)
      end

      def default_params(id, subject = nil)
        if subject.present?
          { from: @from_email, to: @to_email, subject: subject, headers: "Date: DateTime.now\r\nFrom: <#{@from_email}>\r\nTo: #{@to_email}\r\nmessage-id: <#{id}>, attachments: 0 }", message_id: '<' + id + '>' }
        else
          { from: @from_email, to: @to_email, headers: "Date: DateTime.now\r\nFrom: <#{@from_email}>\r\nTo: #{@to_email}\r\nmessage-id: <#{id}>, attachments: 0 }", message_id: '<' + id + '>' }
        end
      end

      def shard_mapping_failed_response
        { account_id: -1, processed_status: 'Shard mapping failed' }
      end

      def inactive_account_response
        { account_id: -1, processed_status: 'Inactive account' }
      end

      def nil_email_response
        { processed_status: 'Invalid from address' }
      end

      def make_parent_ticket
        @account = Account.first
        create_ticket(requester_id: User.first.id)
        parent_ticket = Helpdesk::Ticket.last
        parent_ticket.update_attributes(association_type: 1, subsidiary_tkts_count: 1)
        parent_ticket
      end

      def test_message_id
        id = Faker::Lorem.characters(50)
        params = default_params(id)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        result = incoming_email_handler.message_id
        assert_equal result, id
      end

      def test_message_id_with_space_front_case
        message_id = Faker::Lorem.characters(50)
        id = '     <' + message_id + '>'
        params = { from: @from_email, to: @to_email, headers: "message-id: #{id}\r\nDate: DateTime.now\r\nFrom: <#{@from_email}>\r\nTo: #{@to_email}, attachments: 0" }
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        result = incoming_email_handler.message_id
        assert_equal result, message_id
      end

      def test_message_id_without_space_front_case
        id = Faker::Lorem.characters(50)
        params = { from: @from_email, to: @to_email, headers: "message-id: <#{id}>\r\nDate: DateTime.now\r\nFrom: <#{@from_email}>\r\nTo: #{@to_email}, attachments: 0" }
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        result = incoming_email_handler.message_id
        assert_equal result, id
      end

      def test_message_id_with_space_xmstnefcorrelator_case
        message_id = Faker::Lorem.characters(50)
        id = '     <' + message_id + '>'
        params = { from: @from_email, to: @to_email, headers: "x-ms-tnef-correlator:     #{id}\r\nDate: DateTime.now\r\nFrom: <#{@from_email}>\r\nTo: #{@to_email}, attachments: 0" }
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        result = incoming_email_handler.message_id
        assert_equal result, message_id
      end

      def test_message_id_without_space_xmstnefcorrelator_case
        id = Faker::Lorem.characters(50)
        params = { from: @from_email, to: @to_email, headers: "x-ms-tnef-correlator: <#{id}>\r\nDate: DateTime.now\r\nFrom: <#{@from_email}>\r\nTo: #{@to_email}, attachments: 0" }
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        result = incoming_email_handler.message_id
        assert_equal result, id
      end

      def test_message_id_with_space_middle_case
        message_id = Faker::Lorem.characters(50)
        id = '     <' + message_id + '>'
        params = { from: @from_email, to: @to_email, headers: "Date: DateTime.now\r\nFrom: <#{@from_email}>\r\nTo: #{@to_email}\rmessage-id:  #{id}, attachments: 0" }
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        result = incoming_email_handler.message_id
        assert_equal result, message_id
      end

      def test_message_id_without_space_middle_case
        id = Faker::Lorem.characters(50)
        params = { from: @from_email, to: @to_email, headers: "Date: DateTime.now\r\nFrom: <#{@from_email}>\r\nTo: #{@to_email}\rmessage-id: <#{id}>, attachments: 0" }
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        result = incoming_email_handler.message_id
        assert_equal result, id
      end

      def test_email_spam_watcher_counter
        acc = Account.first
        user_id = ''
        id = Faker::Lorem.characters(50)
        params = default_params(id)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        incoming_email_handler.email_spam_watcher_counter(acc)
        assert_equal $spam_watcher.perform_redis_op('get', acc.id.to_s + '-' + user_id.to_s), nil
      end

      def test_email_spam_watcher_counter_high_count
        acc = Account.first
        Redis.any_instance.stubs(:perform_redis_op).returns(nil, 100)
        Account.any_instance.stubs(:created_at).returns(Time.now.to_i)
        id = Faker::Lorem.characters(50)
        params = default_params(id)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        method_response = incoming_email_handler.email_spam_watcher_counter(acc)
        assert_equal method_response, nil
      end

      def test_email_spam_watcher_counter_errors_out
        acc = Account.first
        Account.any_instance.stubs(:created_at).returns(Time.now.to_i)
        Redis.any_instance.stubs(:perform_redis_op).raises(Exception)
        id = Faker::Lorem.characters(50)
        params = default_params(id)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        method_response = incoming_email_handler.email_spam_watcher_counter(acc)
        assert_equal method_response, nil
      end

      def test_email_perform_collab_reply
        id = Faker::Lorem.characters(50)
        subject = 'Team Huddle - New Message in [#'
        params = default_params(id, subject)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        failed_response = incoming_email_handler.perform
        assert_equal failed_response[:account_id], shard_mapping_failed_response[:account_id]
        assert_equal failed_response[:processed_status], 'No Operation: Collab Email Reply '
      end

      def test_email_perform_no_shardmapping
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        failed_response = incoming_email_handler.perform
        assert_equal failed_response[:account_id], shard_mapping_failed_response[:account_id]
        assert_equal failed_response[:processed_status], shard_mapping_failed_response[:processed_status]
      end

      def test_email_perform_maintenance_shardmapping
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        ShardMapping.any_instance.stubs(:present?).returns(true)
        ShardMapping.any_instance.stubs(:ok?).returns(false)
        ShardMapping.any_instance.stubs(:status).returns(503)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        failed_response = incoming_email_handler.perform
      rescue StandardError => e
        assert_equal failed_response, nil
      end

      def test_email_perform_inactive_account
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        ShardMapping.any_instance.stubs(:present?).returns(true)
        ShardMapping.any_instance.stubs(:ok?).returns(false)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        failed_response = incoming_email_handler.perform
        assert_equal failed_response[:account_id], inactive_account_response[:account_id]
        assert_equal failed_response[:processed_status], inactive_account_response[:processed_status]
      end

      def test_email_perform_with_shardmapping
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        params[:attachments] = 0
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        success_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                          email: 'support@localhost.freshpo.com')
        assert_equal success_response[:processed_status], 'success'
      end

      def test_email_perform_nil_from_email
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        params[:attachments] = 0
        IncomingEmailHandler.any_instance.stubs(:parse_from_email).returns(nil)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        failed_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                         email: 'support@localhost.freshpo.com')
        assert_equal failed_response[:processed_status], nil_email_response[:processed_status]
      end

      def test_email_perform_with_domain_restricted_feature
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        Account.any_instance.stubs(:features?).returns(true)
        params[:attachments] = 0
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        failed_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                         email: 'support@localhost.freshpo.com')
        assert_equal failed_response[:processed_status], 'Restricted domain access'
      end

      def test_email_perform_user_blocked
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        params[:attachments] = 0
        IncomingEmailHandler.any_instance.stubs(:existing_user).returns(User.first)
        User.any_instance.stubs(:blocked?).returns(true)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        failed_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                         email: 'support@localhost.freshpo.com')
        assert_equal 'User blocked', failed_response[:processed_status]
      end

      def test_email_perform_user_not_blocked
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        params[:attachments] = 0
        IncomingEmailHandler.any_instance.stubs(:existing_user).returns(User.first)
        User.any_instance.stubs(:blocked?).returns(false)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        success_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                          email: 'support@localhost.freshpo.com')
        assert_equal 'success', success_response[:processed_status]
      end

      def test_email_perform_from_equals_to
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Account.any_instance.stubs(:email_configs).returns(EmailConfig.first)
        EmailConfig.any_instance.stubs(:find_by_to_email).returns(EmailConfig.first)
        EmailConfig.any_instance.stubs(:reply_email).returns('support@localhost.freshpo.com')
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        params[:attachments] = 0
        params[:from] = 'support@localhost.freshpo.com'
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        failed_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                         email: 'support@localhost.freshpo.com')
        assert_equal 'Email to self', failed_response[:processed_status]
      end

      def test_email_perform_invalid_from
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        params[:attachments] = 0
        params[:from] = 'support@'
        params[:envelope] = { from: 'asdf@' }.to_json
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        failed_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                         email: 'support@localhost.freshpo.com')
        assert_equal 'Invalid from address', failed_response[:processed_status]
      end

      def test_email_perform_invalid_from_valid_envelope
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        params[:attachments] = 0
        params[:from] = 'support@'
        params[:envelope] = { from: 'asdf@testemail.com' }.to_json
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        failed_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                         email: 'support@localhost.freshpo.com')
        assert_equal 'success', failed_response[:processed_status]
      end

      def test_email_perform_nil_account
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Account.stubs(:find_by_full_domain).returns(nil)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        failed_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com')
        assert_equal 'Invalid account', failed_response[:processed_status]
      end

      def test_email_perform_generic_inactive_account
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Account.any_instance.stubs(:active?).returns(false)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        failed_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com')
        assert_equal 'Inactive account', failed_response[:processed_status]
      end

      def test_email_perform_invalid_account
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        Account.any_instance.stubs(:allow_incoming_emails?).returns(false)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        failed_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com')
        assert_equal 'Invalid account', failed_response[:processed_status]
      end

      def test_email_perform_duplicate_email
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        IncomingEmailHandler.any_instance.stubs(:duplicate_email?).returns(true)
        params[:attachments] = 0
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        failed_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                         email: 'support@localhost.freshpo.com')
        assert_equal 'Duplicate email', failed_response[:processed_status]
      end

      def test_email_perform_blank_user_create_error
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        User.any_instance.stubs(:blank?).returns(true)
        User.any_instance.stubs(:signup!).returns(false)
        params[:attachments] = 0
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        failed_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                         email: 'support@localhost.freshpo.com')
      rescue Exception => e
        assert_equal failed_response, nil
      end

      def test_email_perform_no_user
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        User.any_instance.stubs(:blank?).returns(true)
        params[:attachments] = 0
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        failed_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                         email: 'support@localhost.freshpo.com')
        assert_equal 'No User', failed_response[:processed_status]
      end

      def test_email_perform_with_tags
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        params[:attachments] = 0
        params[:migration_tags] = %w[tag1 tag2].to_json
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        failed_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                         email: 'support@localhost.freshpo.com')
        assert_equal 'success', failed_response[:processed_status]
      end

      def test_email_perform_with_text_params
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        params[:attachments] = 0
        params[:text] = 'Hello these are text params'
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        success_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                          email: 'support@localhost.freshpo.com')
        assert_equal success_response[:processed_status], 'success'
      end

      def test_email_perform_with_text_params_and_auto_linking
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        params[:attachments] = 0
        params[:text] = 'Hello these are text params'
        params[:auto_link_done] = 'true'
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        success_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                          email: 'support@localhost.freshpo.com')
        assert_equal success_response[:processed_status], 'success'
      end

      def test_email_perform_with_envelope_to_nil
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        params[:attachments] = 0
        params[:text] = 'Hello these are text params'
        params[:envelope] = { to: nil }.to_json
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        success_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                          email: 'support@localhost.freshpo.com')
        assert_equal success_response[:processed_status], 'success'
      end

      def test_email_perform_with_envelope_to_present
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        params[:attachments] = 0
        params[:text] = 'Hello these are text params'
        params[:envelope] = { to: 'testuser@testuser.com' }.to_json
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        success_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                          email: 'support@localhost.freshpo.com')
        assert_equal success_response[:processed_status], 'success'
      end

      def test_email_perform_content_limit_reached
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        params[:attachments] = 0
        params[:html] = '<b>Hello this is html</b>'
        old = Helpdesk::Email::Constants.safe_send(:remove_const, :MAXIMUM_CONTENT_LIMIT)
        Helpdesk::Email::Constants.const_set(:MAXIMUM_CONTENT_LIMIT, 0)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        success_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                          email: 'support@localhost.freshpo.com')
        Helpdesk::Email::Constants.safe_send(:remove_const, :MAXIMUM_CONTENT_LIMIT)
        Helpdesk::Email::Constants.const_set(:MAXIMUM_CONTENT_LIMIT, old)
        assert_equal success_response[:processed_status], 'success'
      end

      def test_email_perform_content_within_limit
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        params[:attachments] = 0
        params[:html] = '<b>Hello this is html</b>'
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        success_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                          email: 'support@localhost.freshpo.com')
        assert_equal success_response[:processed_status], 'success'
      end

      def test_email_fetch_ticket_nil
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        ticket_response = incoming_email_handler.fetch_ticket(Account.first, { email: 'from_email@email.com' }, User.first, nil)
        assert_equal ticket_response, nil
      end

      def test_email_fetch_ticket_display_id
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        Helpdesk::Ticket.stubs(:extract_id_token).returns(Helpdesk::Ticket.first.try(:display_id))
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        ticket_response = incoming_email_handler.fetch_ticket(Account.first, { email: 'from_email@email.com' }, User.first, nil)
        assert_equal Helpdesk::Ticket.first.try(:id), ticket_response.try(:id)
      end

      def test_email_fetch_ticket_from_headers
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        IncomingEmailHandler.any_instance.stubs(:ticket_from_headers).returns(Helpdesk::Ticket.first)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        ticket_response = incoming_email_handler.fetch_ticket(Account.first, { email: 'from_email@email.com' }, User.first, nil)
        assert_equal Helpdesk::Ticket.first.try(:id), ticket_response.try(:id)
      end

      def test_email_fetch_ticket_from_email_body
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        IncomingEmailHandler.any_instance.stubs(:ticket_from_email_body).returns(Helpdesk::Ticket.first)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        ticket_response = incoming_email_handler.fetch_ticket(Account.first, { email: 'from_email@email.com' }, User.first, nil)
        assert_equal Helpdesk::Ticket.first.try(:id), ticket_response.try(:id)
      end

      def test_email_fetch_ticket_from_id_span
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        IncomingEmailHandler.any_instance.stubs(:ticket_from_id_span).returns(Helpdesk::Ticket.first)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        ticket_response = incoming_email_handler.fetch_ticket(Account.first, { email: 'from_email@email.com' }, User.first, nil)
        assert_equal Helpdesk::Ticket.first.try(:id), ticket_response.try(:id)
      end

      def test_email_perform_with_create_article_fail
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::KbaseArticles.stubs(:create_article_from_email).returns(false)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        IncomingEmailHandler.any_instance.stubs(:kbase_email_present?).returns(true)
        params[:attachments] = 0
        params[:text] = 'Hello these are text params'
        params[:envelope] = { to: 'kbase@localhost.freshpo.com' }.to_json
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        success_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                          email: 'support@localhost.freshpo.com')
        assert_equal 'Article creation failed', success_response[:processed_status]
      end

      def test_email_perform_with_create_article_success
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        Helpdesk::KbaseArticles.stubs(:create_article_from_email).returns(true)
        params[:attachments] = 0
        params[:text] = 'Hello these are text params'
        params[:envelope] = { to: 'kbase@localhost.freshpo.com' }.to_json
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        success_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                          email: 'support@localhost.freshpo.com')
        assert_equal 'success', success_response[:processed_status]
      end

      def test_email_get_user
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        IncomingEmailHandler.any_instance.stubs(:existing_user).returns(nil)
        IncomingEmailHandler.any_instance.stubs(:create_new_user).returns(User.first)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        user_response = incoming_email_handler.get_user(Account.first, 'abc@abc.com', nil, true)
        assert_equal User.first.try(:id), user_response.try(:id)
      end

      def test_handle_system_stack_error
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        params[:attachments] = 0
        params[:html] = '<b>This is an html test</b>'
        IncomingEmailHandler.any_instance.stubs(:get_email_cmd_regex).returns(nil)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        error_response = incoming_email_handler.handle_system_stack_error(SystemStackError.new('system stack test'))
        assert_equal true, error_response.include?('content missing')
      end

      def test_email_perform_content_limit_reached_system_stack_err
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        Helpdesk::HTMLSanitizer.stubs(:html_to_plain_text).raises(SystemStackError.new('system stack err'))
        params[:attachments] = 0
        params[:html] = '<b>Hello this is html</b>'
        old = Helpdesk::Email::Constants.safe_send(:remove_const, :MAXIMUM_CONTENT_LIMIT)
        Helpdesk::Email::Constants.const_set(:MAXIMUM_CONTENT_LIMIT, 0)
        IncomingEmailHandler.any_instance.stubs(:get_email_cmd_regex).returns(nil)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        success_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                          email: 'support@localhost.freshpo.com')
        Helpdesk::Email::Constants.safe_send(:remove_const, :MAXIMUM_CONTENT_LIMIT)
        Helpdesk::Email::Constants.const_set(:MAXIMUM_CONTENT_LIMIT, old)
        assert_equal 'success', success_response[:processed_status]
      end

      def test_email_perform_fetch_archived_ticket
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        Helpdesk::Ticket.stubs(:extract_id_token).returns(nil)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        archived_ticket = incoming_email_handler.fetch_archived_ticket(Account.first, 'abc@abc.com', User.first, nil)
        assert_equal nil, archived_ticket
      end

      def test_email_kbase_exception
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        IncomingEmailHandler.any_instance.stubs(:kbase_email_present?).raises(Exception.new('exception in kbase check test'))
        params[:attachments] = 0
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        success_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                          email: 'support@localhost.freshpo.com')
        assert_equal 'success', success_response[:processed_status]
      end

      def test_email_get_content_ids
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        params['content-ids'] = '1243:first,1234:second'
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        content_ids = incoming_email_handler.get_content_ids
        assert_equal '1243', content_ids['first']
        assert_equal '1234', content_ids['second']
      end

      def test_email_add_notification_text_to_ticket
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        dummy_message = ''
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        Helpdesk::HTMLSanitizer.stubs(:clean).returns("<b>#{dummy_message}</b>")
        text_response = incoming_email_handler.add_notification_text Helpdesk::Ticket.last, dummy_message
        assert_equal true, text_response.include?('<b>')
      end

      def test_email_add_notification_text_to_note
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        dummy_message = ''
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        Helpdesk::HTMLSanitizer.stubs(:clean).returns("<b>#{dummy_message}</b>")
        text_response = incoming_email_handler.add_notification_text Helpdesk::Note.last, dummy_message
        assert_equal true, text_response.include?('<b>')
      end

      def test_incoming_email_fetch_archive_ticket_by_display_id
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        ticket_response = incoming_email_handler.fetch_archive_or_normal_ticket_by_display_id(1500, Account.first, true)
        assert_equal ticket_response, nil
      end

      def test_incoming_email_fetch_normal_ticket_by_display_id
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        ticket_response = incoming_email_handler.fetch_archive_or_normal_ticket_by_display_id(1, Account.first)
        assert_equal Helpdesk::Ticket.first.try(:id), ticket_response.try(:id)
      end

      def test_incoming_email_validates_numericals_in_str
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        numeric_response = incoming_email_handler.is_numeric?('2')
        assert_equal true, numeric_response
      end

      def test_incoming_email_max_limit_reached
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        limit_reached = incoming_email_handler.max_email_limit_reached?('Note', nil, nil)
        assert_equal false, limit_reached
      end

      def test_incoming_email_invalid_from_email
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        invalid_from = incoming_email_handler.invalid_from_email?({ email: nil }, { email: nil }, false)
        assert_equal false, invalid_from
      end

      def test_incoming_email_text_to_html
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        custom_string = "&<>\t\n\"'"
        result_string = incoming_email_handler.text_to_html(custom_string)
        assert_not_equal result_string, custom_string
      end

      def test_incoming_email_check_for_chat_sources
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        ticket_response = incoming_email_handler.check_for_chat_scources(Helpdesk::Ticket.last, domain: Helpdesk::Ticket::CHAT_SOURCES[:snapengage])
        assert_equal ticket_response.try(:id), Helpdesk::Ticket.last.try(:id)
      end

      def test_incoming_email_check_and_mark_as_spam
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        User.any_instance.stubs(:deleted?).returns(true)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        spam_ticket = incoming_email_handler.check_and_mark_as_spam(Helpdesk::Ticket.last)
        assert_equal spam_ticket.try(:id), Helpdesk::Ticket.last.try(:id)
      end

      def test_incoming_email_check_for_auto_responders
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        params[:migration_skip_notification] = true
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        auto_responder_marked = incoming_email_handler.check_for_auto_responders(Helpdesk::Ticket.last)
        assert_equal true, auto_responder_marked
      end

      def test_incoming_email_check_support_emails_from
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        params[:migration_skip_notification] = true
        params[:from] = 'support@localhost.freshpo.com'
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        support_emails = incoming_email_handler
                         .check_support_emails_from(Account.first, Helpdesk::Note.last, User.first, email: Account.first.support_emails.first)
        assert_equal true, support_emails
      end

      def test_incoming_email_check_if_from_fwd_emails
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        Helpdesk::Ticket.any_instance.stubs(:cc_email_hash).returns(fwd_emails: ['anotheruser@test.com'])
        forward_emails = incoming_email_handler.from_fwd_emails?(Helpdesk::Ticket.first, email: 'testuser@abc.com')
        assert_equal false, forward_emails
      end

      def test_incoming_email_check_nil_fwd_emails
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        Helpdesk::Ticket.any_instance.stubs(:cc_email_hash).returns(nil)
        forward_emails = incoming_email_handler.from_fwd_emails?(Helpdesk::Ticket.first, email: 'testuser@abc.com')
        assert_equal false, forward_emails
      end

      def test_incoming_email_ticket_cc_emails_hash
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        ticket_cc_hash = incoming_email_handler.ticket_cc_emails_hash(Helpdesk::Ticket.first, Helpdesk::Note.first)
        assert_equal [], ticket_cc_hash[:fwd_emails]
      end

      def test_incoming_email_check_for_spam_exception
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).raises(Exception.new('sample error'))
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        error_response = incoming_email_handler.check_for_spam(nil)
        assert_equal nil, error_response
      end

      def test_incoming_email_check_primary_with_archive_ticket_feature
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        fake_parent_ticket = make_parent_ticket
        Account.any_instance.stubs(:features_included?).returns(true)
        Helpdesk::SchemaLessTicket.any_instance.stubs(:parent_ticket).returns(fake_parent_ticket.id)
        primary_ticket = incoming_email_handler.check_primary(fake_parent_ticket, Account.first)
        assert_equal nil, primary_ticket
      end

      def test_incoming_email_check_primary
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        fake_parent_ticket = make_parent_ticket
        Helpdesk::SchemaLessTicket.any_instance.stubs(:parent_ticket).returns(fake_parent_ticket.id)
        primary_ticket = incoming_email_handler.check_primary(fake_parent_ticket, Account.first)
        assert_equal nil, primary_ticket
      end

      def test_incoming_email_create_new_user_fails
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        IncomingEmailHandler.any_instance.stubs(:can_create_ticket?).returns(false)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        user_bad_response = incoming_email_handler.create_new_user(nil, { email: nil }, nil, false)
        assert_equal nil, user_bad_response
      end

      def test_incoming_email_ticket_max_email_limit_reached
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        params[:attachments] = 0
        IncomingEmailHandler.any_instance.stubs(:max_email_limit_reached?).returns(true)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        failed_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                         email: 'support@localhost.freshpo.com')
        assert_equal 'Reached max allowed email limit in Ticket/Note', failed_response[:processed_status]
      end

      def test_incoming_email_agent_performed
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        params[:attachments] = 0
        Helpdesk::Ticket.any_instance.stubs(:agent_performed?).returns(true)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        success_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                          email: 'support@localhost.freshpo.com')
        assert_equal 'success', success_response[:processed_status]
      end

      def test_incoming_email_agent_performed_ticket_create_err
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        params[:attachments] = 0
        Helpdesk::Ticket.any_instance.stubs(:agent_performed?).raises(Exception.new('exception in ticket create'))
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        success_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                          email: 'support@localhost.freshpo.com')
        assert_equal 'success', success_response[:processed_status]
      end

      def test_incoming_email_perform_with_attachments
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        params[:attachments] = 1
        Helpdesk::Ticket.any_instance.stubs(:agent_performed?).returns(true)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        success_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                          email: 'support@localhost.freshpo.com')
        assert_equal 'success', success_response[:processed_status]
      end

      def test_email_perform_attachments_error
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        Helpdesk::HTMLSanitizer.stubs(:html_to_plain_text).raises(SystemStackError.new('system stack err'))
        params[:attachments] = 0
        params[:html] = '<b>Hello this is html</b>'
        old = Helpdesk::Email::Constants.safe_send(:remove_const, :MAXIMUM_CONTENT_LIMIT)
        Helpdesk::Email::Constants.const_set(:MAXIMUM_CONTENT_LIMIT, 0)
        IncomingEmailHandler.any_instance.stubs(:get_email_cmd_regex).returns(nil)
        Helpdesk::Attachment.stubs(:create_for_3rd_party).raises(Exception.new('error in attachment'))
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        error_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                        email: 'support@localhost.freshpo.com')
        Helpdesk::Email::Constants.safe_send(:remove_const, :MAXIMUM_CONTENT_LIMIT)
        Helpdesk::Email::Constants.const_set(:MAXIMUM_CONTENT_LIMIT, old)
      rescue Exception => e
        assert_equal nil, error_response
      end

      def test_email_perform_attachments_limit_error
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        Helpdesk::HTMLSanitizer.stubs(:html_to_plain_text).raises(SystemStackError.new('system stack err'))
        params[:attachments] = 0
        params[:html] = '<b>Hello this is html</b>'
        old = Helpdesk::Email::Constants.safe_send(:remove_const, :MAXIMUM_CONTENT_LIMIT)
        Helpdesk::Email::Constants.const_set(:MAXIMUM_CONTENT_LIMIT, 0)
        IncomingEmailHandler.any_instance.stubs(:get_email_cmd_regex).returns(nil)
        Helpdesk::Attachment.stubs(:create_for_3rd_party).raises(HelpdeskExceptions::AttachmentLimitException.new('attachment limit exception'))
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        success_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                          email: 'support@localhost.freshpo.com')
        Helpdesk::Email::Constants.safe_send(:remove_const, :MAXIMUM_CONTENT_LIMIT)
        Helpdesk::Email::Constants.const_set(:MAXIMUM_CONTENT_LIMIT, old)
        assert_equal 'success', success_response[:processed_status]
      end

      def test_email_perform_add_email_to_ticket
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        params[:attachments] = 0
        params[:text] = 'sample text'
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        add_email_response = incoming_email_handler
                             .add_email_to_ticket(Helpdesk::Ticket.first, { email: 'customfrom@test.com' }, { email: 'customto@test.com' }, User.first)
        assert_equal 'success', add_email_response[:processed_status]
      end
    end
  end
end
