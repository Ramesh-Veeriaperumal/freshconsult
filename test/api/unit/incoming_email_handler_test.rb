require_relative '../../api/unit_test_helper'
require_relative '../../core/helpers/tickets_test_helper'
require_relative '../../../lib/email/perform_util'
require_relative '../../core/helpers/note_test_helper'
require_relative '../../core/helpers/users_test_helper.rb'
require_relative '../../core/helpers/account_test_helper.rb'
module Helpdesk
  module Email
    class IncomingEmailHandlerTest < ActionView::TestCase
      include CoreTicketsTestHelper
      include ::Email::PerformUtil
      include NoteTestHelper
      include CoreUsersTestHelper
      include AccountTestHelper

      def setup
        Account.stubs(:current).returns(Account.first)
        Account.stubs(:find_by_full_domain).returns(Account.first)
        @custom_config = Account.current.email_configs.create!(reply_email: 'test@custom.com', to_email: "customcomtest@#{Account.current.full_domain}")
        shard = ShardMapping.first
        shard.status = 200 unless shard.status == 200
        shard.save
        @from_email = Faker::Internet.email
        @to_email = Faker::Internet.email
        @account = Account.current || create_test_account
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        @in_reply_to = "<#{Faker::Internet.email}>"
        @agent_email = @account.technicians.first.email
        @parse_name = Faker::Name.name
        @parse_email = Faker::Internet.email
        @parsed_to_email = { name: Faker::Name.name, email: @custom_config.to_email, domain: @account.full_domain }
        @account.disable_setting(:disable_agent_forward)
        Account.any_instance.stubs(:parse_replied_email_enabled?).returns(true)
      end

      def teardown
        super
        Account.unstub(:current)
        Account.unstub(:find_by_full_domain)
        Helpdesk::Email::SpamDetector.any_instance.unstub :check_spam
        ShardMapping.unstub :fetch_by_domain
        @custom_config.destroy
        Helpdesk::Email::SpamDetector.any_instance.unstub :check_spam
        ShardMapping.unstub :fetch_by_domain
      end

      def default_params(id, subject = nil)
        if subject.present?
          { from: @from_email, to: @to_email, subject: subject, attachments: 0, headers: "Date: DateTime.now\r\nFrom: <#{@from_email}>\r\nTo: #{@to_email}\r\nmessage-id: <#{id}>, attachments: 0 }", message_id: '<' + id + '>' }
        else
          { from: @from_email, to: @to_email, attachments: 0, headers: "Date: DateTime.now\r\nFrom: <#{@from_email}>\r\nTo: #{@to_email}\r\nmessage-id: <#{id}>, attachments: 0 }", message_id: '<' + id + '>' }
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
        ShardMapping.unstub :fetch_by_domain
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        failed_response = incoming_email_handler.perform
        assert_equal failed_response[:account_id], shard_mapping_failed_response[:account_id]
        assert_equal failed_response[:processed_status], shard_mapping_failed_response[:processed_status]
      ensure
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
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
        Helpdesk::Ticket.stubs(:extract_id_token).returns(Account.first.tickets.first.try(:display_id))
        IncomingEmailHandler.any_instance.stubs(:can_be_added_to_ticket?).returns(true)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        ticket_response = incoming_email_handler.fetch_ticket_from_subject(Account.first, { email: 'from_email@email.com' }, User.first, nil)
        assert_equal Account.first.tickets.first.try(:id), ticket_response.try(:id)
      end

      def test_email_fetch_ticket_from_headers
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        IncomingEmailHandler.any_instance.stubs(:ticket_from_headers).returns(Account.first.tickets.first)
        IncomingEmailHandler.any_instance.stubs(:can_be_added_to_ticket?).returns(true)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        ticket_response = incoming_email_handler.fetch_ticket_from_references(Account.first, { email: 'from_email@email.com' }, User.first, nil)
        assert_equal Account.first.tickets.first.try(:id), ticket_response.try(:id)
      end

      def test_email_fetch_ticket_from_email_body
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        IncomingEmailHandler.any_instance.stubs(:ticket_from_email_body).returns(Account.first.tickets.first)
        IncomingEmailHandler.any_instance.stubs(:can_be_added_to_ticket?).returns(true)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        ticket_response = incoming_email_handler.fetch_ticket_from_email_body(Account.first, { email: 'from_email@email.com' }, User.first)
        assert_equal Account.first.tickets.first.try(:id), ticket_response.try(:id)
      end

      def test_email_fetch_ticket_from_id_span
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        IncomingEmailHandler.any_instance.stubs(:ticket_from_id_span).returns(Account.first.tickets.first)
        IncomingEmailHandler.any_instance.stubs(:can_be_added_to_ticket?).returns(true)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        ticket_response = incoming_email_handler.fetch_ticket_from_id_span(Account.first, { email: 'from_email@email.com' }, User.first)
        assert_equal Account.first.tickets.first.try(:id), ticket_response.try(:id)
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
        ticket_response = incoming_email_handler.fetch_archive_or_normal_ticket_by_display_id(Account.first.tickets.first.try(:display_id), Account.first)
        assert_equal Account.first.tickets.first.try(:id), ticket_response.try(:id)
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

      def test_prevent_lang_detect_for_spam
        account = Account.current
        user = account.users.first
        user.language = 'ar'
        user.save
        ticket = account.tickets.first
        ticket.spam = true
        assign_language(user, account, ticket)
        user = account.users.find_by_id(user.id)
        assert_equal account.language, user.language
      end

      def test_lang_detect_for_non_spam
        account = Account.current
        user = account.users.first
        user.language = 'ar'
        user.save
        ticket = account.tickets.first
        ticket.spam = false
        text = Faker::Lorem.characters(10)
        Users::DetectLanguage.any_instance.stubs(:detect_lang_from_email_service).returns('fr')
        Users::DetectLanguage.new.perform(user_id: user.id, text: text)
        user = account.users.where(id: user.id).first
        assert_equal 'fr', user.language
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

      def test_incoming_email_ticket_cc_emails_hash_with_reply_cc_email
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        params[:cc] = [Faker::Internet.email, Faker::Internet.email, Faker::Internet.email]
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        ticket_cc_hash = incoming_email_handler.ticket_cc_emails_hash(Helpdesk::Ticket.first, Helpdesk::Note.first)
        assert_equal params[:cc], ticket_cc_hash[:reply_cc]
      end

      def test_incoming_email_ticket_cc_emails_hash_with_customer_reply
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ticket = create_ticket(requester_id: User.first.id)
        ticket_cc_email = Faker::Internet.email
        ticket.cc_email[:cc_emails] = [ticket_cc_email]
        ticket.cc_email[:reply_cc] = [ticket_cc_email]
        ticket.save
        user = add_agent(Account.current, email: ticket_cc_email)
        note = create_note(user_id: user.id, ticket_id: Helpdesk::Ticket.first.id, account_id: Account.current.id)
        note_cc_email = Faker::Internet.email
        note.cc_emails = [note_cc_email]
        note.save
        params[:cc] = [note_cc_email]
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        ticket_cc_hash = incoming_email_handler.ticket_cc_emails_hash(ticket, note)
        assert_equal ticket_cc_hash[:reply_cc].include?(note_cc_email), true
        assert_equal ticket_cc_hash[:reply_cc].include?(ticket_cc_email), true
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

      def test_incoming_email_check_primary_with_archive_ticket_feature_when_ticket_parent_is_set
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        @account = Account.current
        ticket = create_ticket(requester_id: User.first.id)
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        fake_parent_ticket = make_parent_ticket
        ticket.parent = fake_parent_ticket
        Account.any_instance.stubs(:features_included?).returns(true)
        Helpdesk::SchemaLessTicket.any_instance.stubs(:parent_ticket).returns(fake_parent_ticket.id)
        primary_ticket = incoming_email_handler.check_primary(ticket, Account.first)
        assert_equal fake_parent_ticket, primary_ticket
      ensure
        Account.any_instance.unstub(:features_included?)
        Helpdesk::SchemaLessTicket.any_instance.unstub(:parent_ticket)
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

      def test_incoming_email_perform_with_email_spoof_check
        Account.any_instance.stubs(:email_spoof_check_feature?).returns(true)
        Helpdesk::Ticket.any_instance.stubs(:save_ticket!).returns(true)
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

      def test_failure_email_with_wildcards_no_config
        Account.current.launch(:prevent_wc_ticket_create)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        params = default_params(Faker::Lorem.characters(50), 'Test Subject')
        params[:to] = "test+1223@#{Account.current.full_domain}"
        parsed_to_email = { name: 'test', email: "test+1223@#{Account.current.full_domain}", domain: Account.current.full_domain }
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        failed_response = incoming_email_handler.perform(parsed_to_email)
        assert_equal 'Wildcard Email ', failed_response[:processed_status]
      ensure
        ShardMapping.unstub(:fetch_by_domain)
        Account.any_instance.unstub(:email_configs)
        EmailConfig.any_instance.unstub(:find_by_to_email)
        Account.current.rollback(:prevent_wc_ticket_create)
      end

      def test_success_email_to_the_wild_cards
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::IncomingEmailHandler.any_instance.stubs(:add_to_or_create_ticket).returns(true)
        params = default_params(Faker::Lorem.characters(50), 'Test Subject')
        params[:to] = "test+1223@#{Account.current.full_domain}"
        parsed_to_email = { name: 'test', email: "test+1223@#{Account.current.full_domain}", domain: Account.current.full_domain }
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        assert_equal incoming_email_handler.perform(parsed_to_email), true
      ensure
        ShardMapping.unstub(:fetch_by_domain)
        Account.any_instance.unstub(:email_configs)
        EmailConfig.any_instance.unstub(:find_by_to_email)
        Helpdesk::Email::IncomingEmailHandler.any_instance.unstub(:add_to_or_create_ticket)
      end

      def test_success_email_to_the_wild_cards_using_allow_check
        Account.current.launch(:prevent_wc_ticket_create)
        Account.current.launch(:allow_wildcard_ticket_create)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::IncomingEmailHandler.any_instance.stubs(:add_to_or_create_ticket).returns(true)
        params = default_params(Faker::Lorem.characters(50), 'Test Subject')
        params[:to] = "test+1223@#{Account.current.full_domain}"
        parsed_to_email = { name: 'test', email: "test+1223@#{Account.current.full_domain}", domain: Account.current.full_domain }
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        assert_equal incoming_email_handler.perform(parsed_to_email), true
      ensure
        ShardMapping.unstub(:fetch_by_domain)
        Account.any_instance.unstub(:email_configs)
        EmailConfig.any_instance.unstub(:find_by_to_email)
        Helpdesk::Email::IncomingEmailHandler.any_instance.unstub(:add_to_or_create_ticket)
        Account.current.rollback(:prevent_wc_ticket_create)
        Account.current.rollback(:allow_wildcard_ticket_create)
      end

      def test_success_email_to_the_default_support_mailbox
        Account.current.launch(:prevent_wc_ticket_create)
        config = Account.current.email_configs.first
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Account.any_instance.stubs(:email_configs).returns(config)
        EmailConfig.any_instance.stubs(:find_by_to_email).returns(config)
        Helpdesk::Email::IncomingEmailHandler.any_instance.stubs(:add_to_or_create_ticket).returns(true)
        params = default_params(Faker::Lorem.characters(50), 'Test Subject')
        params[:to] = config.reply_email
        parsed_to_email = { name: 'test', email: config.to_email, domain: Account.current.full_domain }
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        assert_equal incoming_email_handler.perform(parsed_to_email), true
      ensure
        ShardMapping.unstub(:fetch_by_domain)
        Account.any_instance.unstub(:email_configs)
        EmailConfig.any_instance.unstub(:find_by_to_email)
        Helpdesk::Email::IncomingEmailHandler.any_instance.unstub(:add_to_or_create_ticket)
        Account.current.rollback(:prevent_wc_ticket_create)
      end

      def test_email_perform_save_incoming_time
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        params[:x_received_at] = Time.now.utc.iso8601
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        params[:attachments] = 0
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        success_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                          email: 'support@localhost.freshpo.com')
        assert_equal success_response[:processed_status], 'success'
      end

      def test_email_perform_save_incoming_time_internal_date
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        params[:internal_date] = Time.zone.now.to_s
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        params[:attachments] = 0
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        success_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                          email: 'support@localhost.freshpo.com')
        assert_equal success_response[:processed_status], 'success'
      end

      def test_email_perform_to_throw_exception_with_sane_restricted_helpdesk
        params = default_params(Faker::Lorem.characters(50), 'Test Subject')
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        account = Account.current
        account.revoke_feature :domain_restricted_access
        account.add_feature :restricted_helpdesk
        account.launch :allow_wildcard_ticket_create
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        failed_response = incoming_email_handler.perform(domain: 'localhost.freshpo.com',
                                                         email: Faker::Internet.email)
        assert_equal failed_response[:processed_status], 'No User'
      ensure
        account.rollback :allow_wildcard_ticket_create
        account.revoke_feature :restricted_helpdesk
        Helpdesk::Email::SpamDetector.any_instance.unstub :check_spam
        ShardMapping.unstub :fetch_by_domain
      end

      def test_show_quoted_text_with_plain_as_true
        $redis_others.perform_redis_op('set', QUOTED_TEXT_PARSE_FROM_REGEX, '(from|von|fra|van)')
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        params[:attachments] = 0
        params[:text] = 'sample text. Van: Test <test@tabsnot.space>'
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        show_quoted_text_plain = incoming_email_handler.show_quoted_text(params[:text], Account.current.tickets.first.reply_email)
        assert_equal 'sample text. ', show_quoted_text_plain[:body]
        assert_equal params[:text], show_quoted_text_plain[:full_text]
      ensure
        ShardMapping.unstub(:fetch_by_domain)
        Helpdesk::Email::SpamDetector.any_instance.unstub(:check_spam)
        $redis_others.perform_redis_op('del', QUOTED_TEXT_PARSE_FROM_REGEX)
      end

      def test_show_quoted_text_with_plain_as_false
        $redis_others.perform_redis_op('set', QUOTED_TEXT_PARSE_FROM_REGEX, '(from|von|fra|van)')
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        params[:attachments] = 0
        params[:text] = 'sample text. Van: Test <test@tabsnot.space>'
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        show_quoted_text_non_plain = incoming_email_handler.show_quoted_text(params[:text], Account.current.tickets.first.reply_email, false)
        returned_body = '<p>sample text. </p><div class=\'freshdesk_quote\'><blockquote class=\'freshdesk_quote\'><p>Van: Test <test></test></p></blockquote></div>'
        assert_equal returned_body, show_quoted_text_non_plain[:body]
        assert_equal returned_body, show_quoted_text_non_plain[:full_text]
      ensure
        ShardMapping.unstub(:fetch_by_domain)
        Helpdesk::Email::SpamDetector.any_instance.unstub(:check_spam)
        $redis_others.perform_redis_op('del', QUOTED_TEXT_PARSE_FROM_REGEX)
      end

      def test_show_quoted_text_fail_when_redis_key_not_set
        redis_key_set = false
        if $redis_others.perform_redis_op('get', QUOTED_TEXT_PARSE_FROM_REGEX)
          redis_key_set = true
          $redis_others.perform_redis_op('del', QUOTED_TEXT_PARSE_FROM_REGEX)
        end
        id = Faker::Lorem.characters(50)
        subject = 'Test Subject'
        params = default_params(id, subject)
        ShardMapping.stubs(:fetch_by_domain).returns(ShardMapping.first)
        Helpdesk::Email::SpamDetector.any_instance.stubs(:check_spam).returns(spam: nil)
        params[:attachments] = 0
        params[:text] = 'sample text. Van: Test <test@tabsnot.space>'
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(params)
        show_quoted_text = incoming_email_handler.show_quoted_text(params[:text], Account.current.tickets.first.reply_email)
        assert_equal params[:text], show_quoted_text[:body]
        assert_equal params[:text], show_quoted_text[:full_text]
      ensure
        ShardMapping.unstub(:fetch_by_domain)
        Helpdesk::Email::SpamDetector.any_instance.unstub(:check_spam)
        $redis_others.perform_redis_op('set', QUOTED_TEXT_PARSE_FROM_REGEX, '(from|von|fra|van)') if redis_key_set
      end
      
      # Try creating ticket if the message params does not contain "in-reply-to" which will be present only for replied/forwarded mails
      def test_create_ticket_with_composed_email_feature_enabled
        Account.any_instance.stubs(:composed_email_check_enabled?).returns(true)
        req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
        req_params[:attachments] = 0
        req_params[:from] = @agent_email
        req_params[:text] = "<p>this is a test email</p>\n------\nFrom: #{@parse_name} <#{@parse_email}>\nTo: qwe@tyu.com\nSubject: test subject 123\n-----\n"
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(req_params)
        result = incoming_email_handler.perform(@parsed_to_email)
        Sharding.select_shard_of(@parsed_to_email[:domain]) do
          ticket = @account.tickets.where(id: result[:ticket_id]).first
          ticket_requester = @account.users.reload.where(id: ticket.requester_id).first
          # Assert if 'from' field in message params is equal to the requestor in the ticket as this is a composed mail
          assert_equal req_params[:from], ticket_requester.email
        end
      end

      # Try creating ticket if the message params does not contain "in-reply-to" which will be present only for replied/forwarded mails
      def test_create_ticket_with_composed_email_feature_disabled
        Account.any_instance.stubs(:composed_email_check_enabled?).returns(false)
        req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
        req_params[:attachments] = 0
        req_params[:from] = @agent_email
        req_params[:text] = "<p>this is a test email</p>\n------\nFrom: #{@parse_name} <#{@parse_email}>\nTo: qwe@tyu.com\nSubject: test subject 123\n-----\n"
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(req_params)
        result = incoming_email_handler.perform(@parsed_to_email)
        Sharding.select_shard_of(@parsed_to_email[:domain]) do
          ticket = @account.tickets.where(id: result[:ticket_id]).first
          ticket_requester = @account.users.reload.where(id: ticket.requester_id).first
          # Assert if the ticket requester is equal to email parsed from the quoted message since the launch-party feature is disabled
          assert_equal @parse_email, ticket_requester.email
        end
      end

      # Try creating ticket if the message params contains "in-reply-to". This should be irregardless of the feature
      def test_create_ticket_with_forwarded_email
        req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
        req_params[:in_reply_to] = @in_reply_to
        req_params[:attachments] = 0
        req_params[:from] = @agent_email
        req_params[:text] = "<p>this is a test email</p>\n------\nFrom: #{@parse_name} <#{@parse_email}>\nTo: qwe@tyu.com\nSubject: test subject\n-----\n"
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(req_params)
        result = incoming_email_handler.perform(@parsed_to_email)
        Sharding.select_shard_of(@parsed_to_email[:domain]) do
          ticket = @account.tickets.where(id: result[:ticket_id]).first
          ticket_requester = @account.users.reload.where(id: ticket.requester_id).first
          # Assert if 'from' field in message params is not equal to the requestor in the ticket as this is a forwarded mail
          # Assuming that the toggle for :disable_agent_forward is false
          assert_equal @parse_email, ticket_requester.email
        end
      end
    
      def test_create_ticket_agent_replies_eng
        req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
        req_params[:in_reply_to] = @in_reply_to
        req_params[:from] = @agent_email
        req_params[:text] = "this is a sample test mail.Regards,V\nOn Thu, Apr 9, 2020 at 6:57 PM #{@parse_name} <#{@parse_email}> wrote:\nTesting 5, reply 1\nOn Thu, Apr 9, 2020 at 6:57 PM Rio <palermo@gmail.com> wrote:\ncheck 1. testing 5"
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(req_params)
        ticket_creation_status = incoming_email_handler.perform(@parsed_to_email)
        Sharding.select_shard_of(@parsed_to_email[:domain]) do
          ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
          ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
          assert_equal @parse_email, ticket_requestor.email
        end
      end

      def test_create_ticket_agent_forwards_eng
        req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
        req_params[:in_reply_to] = @in_reply_to
        req_params[:from] = @agent_email
        req_params[:text] = "This is a forwarded message!\n\n---------- Forwarded message ---------\nFrom: #{@parse_name} <#{@parse_email}>\nDate: Thu, Apr 9, 2020 at 6:57 PM\nSubject: Re: demo testing 5\nTo: Rio <palermo@gmail.com>, <qwerty1234@yahoo.com>\nCc: LISBON MUMBAI <pamela.stockholm@test987.edu>\n\n\nTesting 5, reply 1\nOn Thu, Apr 9, 2020 at 6:57 PM Rio <palermo@gmail.com> wrote:\ncheck 1. testing 5"
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(req_params)
        ticket_creation_status = incoming_email_handler.perform(@parsed_to_email)
        Sharding.select_shard_of(@parsed_to_email[:domain]) do
          ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
          ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
          assert_equal @parse_email, ticket_requestor.email
        end
      end

      def test_create_ticket_agent_replies_esp
        req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
        req_params[:in_reply_to] = @in_reply_to
        req_params[:from] = @agent_email
        req_params[:text] = "junto a los mensajes enviados a mi direcciMostrarnnn (no a una lista de distribuci Unannn), y ) al lado duna flecha doble ( flecha (\n\n\nEl vie., 24 abr. 2020 a las 11:37, #{@parse_name} (<#{@parse_email}>) escribi:::\nFYI please.\nOn Sat, Apr 11, 2020 at 10:26 AM Rio <palermo@gmail.com> wrote:\ntesting 2\nOn Sat, Apr 11, 2020 at 10:25 AM qwerty <qwerty1234@gmail.com> wrote:\ntesting 1"
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(req_params)
        ticket_creation_status = incoming_email_handler.perform(@parsed_to_email)
        Sharding.select_shard_of(@parsed_to_email[:domain]) do
          ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
          ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
          assert_equal @parse_email, ticket_requestor.email
        end
      end

      def test_create_ticket_agent_forwards_esp
        req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
        req_params[:in_reply_to] = @in_reply_to
        req_params[:from] = @agent_email
        req_params[:text] = "de distribuci Unannn), y ) al lado duna flecha doble ( flecha (\n\n\nEl vie., 24 abr. 2020 a las 11:37,\n\n---------- Forwarded message ---------\nDe: #{@parse_name} <#{@parse_email}>\nDate: vie., 24 abr. 2020 a las 11:37\nSubject: Re: testing reply-to 1\nTo: Rio <palermo@gmail.com>\nCc: <qwerty1234@yahoo.com>, Lisbon Tokyo <pamelamay20@gmail.com>, <support@angrynerds1993.freshpo.com>\n\n\nFYI please.\nOn Sat, Apr 11, 2020 at 10:26 AM Rio <palermo@gmail.com> wrote:\ntesting 2\nOn Sat, Apr 11, 2020 at 10:25 AM qwerty <qwerty1234@gmail.com> wrote:\ntesting 1"
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(req_params)
        ticket_creation_status = incoming_email_handler.perform(@parsed_to_email)
        Sharding.select_shard_of(@parsed_to_email[:domain]) do
          ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
          ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
          assert_equal @parse_email, ticket_requestor.email
        end
      end

      def test_create_ticket_agent_replies_deutshe
        req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
        req_params[:in_reply_to] = @in_reply_to
        req_params[:from] = @agent_email
        req_params[:text] = "testemailB dnjdndf. dknfjan\nAm Fr., 24. Apr. 2020 um 13:05B Uhr schrieb #{@parse_name} <#{@parse_email}>:\nPFA. Thanks & Regards\nOn Wed, Apr 8, 2020 at 12:08 PM John Wick <qwerty1234@outlook.com> wrote:\nPlease check.From: John Wick <qwerty1234@outlook.com>\nSent: 08 April 2020 11:46\nTo: Rio <palermo@gmail.com>; qwerty <qwerty1234@gmail.com>; support@angrynerds1993.freshpo.com <support@angrynerds1993.freshpo.com>\nCc: LISBON MUMBAI <pamela.stockholm@test987.edu>; Lisbon Tokyo <pamelamay20@gmail.com>\nSubject: Re: Another test mailB Please look into it.\nRegards,V"
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(req_params)
        ticket_creation_status = incoming_email_handler.perform(@parsed_to_email)
        Sharding.select_shard_of(@parsed_to_email[:domain]) do
          ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
          ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
          assert_equal @parse_email, ticket_requestor.email
        end
      end

      def test_create_ticket_agent_forwards_deutshe
        req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
        req_params[:in_reply_to] = @in_reply_to
        req_params[:from] = @agent_email
        req_params[:text] = "forwajdnd dnfsjf\n\n---------- Forwarded message ---------\nVon: #{@parse_name} <#{@parse_email}>\nDate: Fr., 24. Apr. 2020 um 13:05B Uhr\nSubject: Re: Another test mail\nTo: John Wick <qwerty1234@outlook.com>\nCc: Rio <palermo@gmail.com>, LISBON MUMBAI <pamela.stockholm@test987.edu>, Lisbon Tokyo <pamelamay20@gmail.com>, <support@angrynerds1993.freshpo.com>\n\n\nPFA. Thanks & Regards\nAm Fr., 24. Apr. 2020 um 13:05B Uhr schrieb qwerty <qwerty1234@gmail.com>:\nPlease check.From: John Wick <qwerty1234@outlook.com>\nSent: 08 April 2020 11:46\nTo: Rio <palermo@gmail.com>; qwerty <qwerty1234@gmail.com>; support@angrynerds1993.freshpo.com <support@angrynerds1993.freshpo.com>\nCc: LISBON MUMBAI <pamela.stockholm@test987.edu>; Lisbon Tokyo <pamelamay20@gmail.com>\nSubject: Re: Another test mailB Please look into it.\nRegards,V"
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(req_params)
        ticket_creation_status = incoming_email_handler.perform(@parsed_to_email)
        Sharding.select_shard_of(@parsed_to_email[:domain]) do
          ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
          ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
          assert_equal @parse_email, ticket_requestor.email
        end
      end

      def test_create_ticket_agent_replies_dutch
        req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
        req_params[:in_reply_to] = @in_reply_to
        req_params[:from] = @agent_email
        req_params[:text] = "djnsnvsjB dgnnksvB djns\nOp za 11 apr. 2020 om 14:43 schreef #{@parse_name} <#{@parse_email}>:\nAnother hi\nOn Sat, Apr 11, 2020 at 2:42 PM John Wick <qwerty1234@outlook.com> wrote:\nSay hiFrom: Denver ghuio <bogotacena@outlook.com>\nSent: 11 April 2020 13:49\nTo: qwerty1234@outlook.com <qwerty1234@outlook.com>\nSubject: TestB Hi"
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(req_params)
        ticket_creation_status = incoming_email_handler.perform(@parsed_to_email)
        Sharding.select_shard_of(@parsed_to_email[:domain]) do
          ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
          ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
          assert_equal @parse_email, ticket_requestor.email
        end
      end

      def test_create_ticket_agent_forwards_dutch
        req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
        req_params[:in_reply_to] = @in_reply_to
        req_params[:from] = @agent_email
        req_params[:text] = "dnfjsnfB djfnsjf\n\n---------- Forwarded message ---------\nVan: #{@parse_name} <#{@parse_email}>\nDate: za 11 apr. 2020 om 14:43\nSubject: Re: Test\nTo: John Wick <qwerty1234@outlook.com>\nCc: palermo@gmail.com <palermo@gmail.com>, pamela.stockholm@test987.edu <pamela.stockholm@test987.edu>\n\n\nAnother hi\nOn Sat, Apr 11, 2020 at 2:42 PM John Wick <qwerty1234@outlook.com> wrote:\nSay hiFrom: Denver ghuio <bogotacena@outlook.com>\nSent: 11 April 2020 13:49\nTo: qwerty1234@outlook.com <qwerty1234@outlook.com>\nSubject: TestB"
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(req_params)
        ticket_creation_status = incoming_email_handler.perform(@parsed_to_email)
        Sharding.select_shard_of(@parsed_to_email[:domain]) do
          ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
          ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
          assert_equal @parse_email, ticket_requestor.email
        end
      end

      def test_create_ticket_agent_replies_french
        req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
        req_params[:in_reply_to] = @in_reply_to
        req_params[:from] = @agent_email
        req_params[:text] = "djnfsf jdnf Le\nLeB sam. 11 avr. 2020 C B 10:43, #{@parse_name} <#{@parse_email}> a C)critB :\ndemo"
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(req_params)
        ticket_creation_status = incoming_email_handler.perform(@parsed_to_email)
        Sharding.select_shard_of(@parsed_to_email[:domain]) do
          ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
          ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
          assert_equal @parse_email, ticket_requestor.email
        end
      end

      def test_create_ticket_agent_forwards_french
        req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
        req_params[:in_reply_to] = @in_reply_to
        req_params[:from] = @agent_email
        req_params[:text] = "kdfknsf\n\n---------- Forwarded message ---------\nDe : #{@parse_name} <#{@parse_email}>\nDate: sam. 11 avr. 2020 C B 10:43\nSubject: test\nTo: qwerty <qwerty1234@gmail.com>\n\n\ndemo"
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(req_params)
        ticket_creation_status = incoming_email_handler.perform(@parsed_to_email)
        Sharding.select_shard_of(@parsed_to_email[:domain]) do
          ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
          ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
          assert_equal @parse_email, ticket_requestor.email
        end
      end

      def test_create_ticket_agent_replies_portuguese
        req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
        req_params[:in_reply_to] = @in_reply_to
        req_params[:from] = @agent_email
        req_params[:text] = "dfadf\n#{@parse_name} <#{@parse_email}> escreveu no dia sC!bado, 11/04/2020 C (s) 11:01:\n yes this is demo\n On Saturday, 11 April 2020, 10:44:01 GMT+5:30, qwerty <qwerty1234@gmail.com> wrote: \n \n demo"
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(req_params)
        ticket_creation_status = incoming_email_handler.perform(@parsed_to_email)
        Sharding.select_shard_of(@parsed_to_email[:domain]) do
          ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
          ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
          assert_equal @parse_email, ticket_requestor.email
        end
      end

      def test_create_ticket_agent_forwards_portuguese
        req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
        req_params[:in_reply_to] = @in_reply_to
        req_params[:from] = @agent_email
        req_params[:text] = "dfsfsdfdsf\ndfdff\n---------- Forwarded message ---------\nDe: #{@parse_name} <#{@parse_email}>\nDate: sC!bado, 11/04/2020 C (s) 11:01\nSubject: Re: test\nTo: qwerty <qwerty1234@gmail.com>\n\n\n yes this is demo\n On Saturday, 11 April 2020, 10:44:01 GMT+5:30, qwerty <qwerty1234@gmail.com> wrote: \n \n demo"
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(req_params)
        ticket_creation_status = incoming_email_handler.perform(@parsed_to_email)
        Sharding.select_shard_of(@parsed_to_email[:domain]) do
          ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
          ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
          assert_equal @parse_email, ticket_requestor.email
        end
      end

      def test_create_ticket_agent_replies_oth_locale
        req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
        req_params[:in_reply_to] = @in_reply_to
        req_params[:from] = @agent_email
        req_params[:text] = "dnfdjn njfiw VypnDjnsjdndsns pre jazyk: anglitinaB \nne 12. 4. 2020 oB 11:12 #{@parse_name} <#{@parse_email}> napC-sal(a):\n how abt this ?\n On Sunday, 12 April 2020, 11:10:32 GMT+5:30, qwerty <qwerty1234@gmail.com> wrote: \n \n checking\nOn Sun, Apr 12, 2020 at 10:59 AM qwerty <qwerty1234@gmail.com> wrote:\nhiiii\nOn Sun, Apr 12, 2020 at 10:47 AM John Wick <qwerty1234@outlook.com> wrote:\nplease check.From: John Wick <qwerty1234@outlook.com>\nSent: 09 April 2020 15:10\nTo: Rio <palermo@gmail.com>; qwerty <qwerty1234@gmail.com>\nCc: LISBON MUMBAI <pamela.stockholm@test987.edu>; bogotacena@outlook.com <bogotacena@outlook.com>\nSubject: Re: test forward featureB Reply no. 2From: Rio <palermo@gmail.com>\nSent: 09 April 2020 15:09\nTo: John Wick <qwerty1234@outlook.com>\nCc: Lisbon Tokyo <pamelamay20@gmail.com>; LISBON MUMBAI <pamela.stockholm@test987.edu>; bogotacena@outlook.com <bogotacena@outlook.com>\nSubject:fdfdf"
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(req_params)
        ticket_creation_status = incoming_email_handler.perform(@parsed_to_email)
        Sharding.select_shard_of(@parsed_to_email[:domain]) do
          ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
          ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
          assert_equal @parse_email, ticket_requestor.email
        end
      end

      def test_create_ticket_agent_replies_eng_feature_disabled
        Account.any_instance.stubs(:parse_replied_email_enabled?).returns(false)
        req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
        req_params[:in_reply_to] = @in_reply_to
        req_params[:from] = @agent_email
        from_name = Faker::Name.name
        from_email = Faker::Internet.email
        req_params[:text] = "this is a sample test mail.Regards,V\nOn Thu, Apr 9, 2020 at 6:57 PM #{@parse_name} <#{@parse_email}> wrote:\nTesting 5, reply 1\nOn Thu, Apr 9, 2020 at 6:57 PM Rio <palermo@gmail.com> wrote:\nFrom: #{from_name} <#{from_email}> check 1. testing 5"
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(req_params)
        ticket_creation_status = incoming_email_handler.perform(@parsed_to_email)
        Sharding.select_shard_of(@parsed_to_email[:domain]) do
          ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
          ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
          assert_equal from_email, ticket_requestor.email
        end
      end

      def test_create_ticket_agent_replies_eng_long_email_line_break1
        req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
        req_params[:in_reply_to] = @in_reply_to
        req_params[:from] = @agent_email
        req_params[:text] = "this is a sample test mail.Regards,V\nOn Thu, Apr 9, 2020 at 6:57 PM #{@parse_name} <\n#{@parse_email}> wrote:\nTesting 5, reply 1\nOn Thu, Apr 9, 2020 at 6:57 PM Rio <palermo@gmail.com> wrote:\ncheck 1. testing 5"
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(req_params)
        ticket_creation_status = incoming_email_handler.perform(@parsed_to_email)
        Sharding.select_shard_of(@parsed_to_email[:domain]) do
          ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
          ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
          assert_equal @parse_email, ticket_requestor.email
        end
      end

      def test_create_ticket_agent_replies_eng_email_line_break2
        req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
        req_params[:in_reply_to] = @in_reply_to
        req_params[:from] = @agent_email
        req_params[:text] = "this is a sample test mail.Regards,V\nOn Thu, Apr 9, 2020 at 6:57 PM #{@parse_name} <#{@parse_email}\n> wrote:\nTesting 5, reply 1\nOn Thu, Apr 9, 2020 at 6:57 PM Rio <palermo@gmail.com> wrote:\ncheck 1. testing 5"
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(req_params)
        ticket_creation_status = incoming_email_handler.perform(@parsed_to_email)
        Sharding.select_shard_of(@parsed_to_email[:domain]) do
          ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
          ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
          assert_equal @parse_email, ticket_requestor.email
        end
      end

      def test_create_ticket_agent_replies_eng_long_name_line_break
        req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
        req_params[:in_reply_to] = @in_reply_to
        req_params[:from] = @agent_email
        test_name = Faker::Name.name
        req_params[:text] = "this is a sample test mail.Regards,V\nOn Thu, Apr 9, 2020 at 6:57 PM #{@parse_name}\n#{test_name} <#{@parse_email}> wrote:\nTesting 5, reply 1\nOn Thu, Apr 9, 2020 at 6:57 PM Rio <palermo@gmail.com> wrote:\ncheck 1. testing 5"
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(req_params)
        ticket_creation_status = incoming_email_handler.perform(@parsed_to_email)
        Sharding.select_shard_of(@parsed_to_email[:domain]) do
          ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
          ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
          assert_equal @parse_email, ticket_requestor.email
        end
      end

      def test_create_ticket_agent_replies_eng_line_break
        req_params = default_params(Faker::Lorem.characters(50), Faker::Company.bs)
        req_params[:in_reply_to] = @in_reply_to
        req_params[:from] = @agent_email
        test_name = Faker::Name.name
        req_params[:text] = "this is a sample test mail.Regards,V\nOn Thu, Apr 9, 2020 at 6:57 PM #{@parse_name} \n<#{@parse_email}> wrote:\nTesting 5, reply 1\nOn Thu, Apr 9, 2020 at 6:57 PM Rio <palermo@gmail.com> wrote:\ncheck 1. testing 5"
        incoming_email_handler = Helpdesk::Email::IncomingEmailHandler.new(req_params)
        ticket_creation_status = incoming_email_handler.perform(@parsed_to_email)
        Sharding.select_shard_of(@parsed_to_email[:domain]) do
          ticket = @account.tickets.where(id: ticket_creation_status[:ticket_id]).first
          ticket_requestor = @account.users.reload.where(id: ticket.requester_id).first
          assert_equal @parse_email, ticket_requestor.email
        end
      end
    end
  end
end
