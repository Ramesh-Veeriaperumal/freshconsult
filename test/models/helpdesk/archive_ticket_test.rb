require_relative '../test_helper'
['tickets_test_helper.rb', 'archive_ticket_test_helper.rb', 'ticket_fields_test_helper.rb'].each { |file| require Rails.root.join('test', 'api', 'helpers', file) }
['account_helper.rb', 'user_helper.rb'].each { |file| require Rails.root.join('spec', 'support', file) }
['companies_test_helper.rb'].each { |file| require Rails.root.join('test', 'core', 'helpers', file) }

class ArchiveTicketTest < ActiveSupport::TestCase
  include ArchiveTicketTestHelper
  include ApiTicketsTestHelper
  include AccountHelper
  include UsersHelper
  include ModelsCompaniesTestHelper
  include TicketFieldsTestHelper

  def ticket_association_s3_stub(email, status_update_time, custom_hash = {})
    ticket_stub_hash = {
      'helpdesk_tickets' => {
        'cc_email' => [email]
      },
      'helpdesk_tickets_association' => {
        'ticket_states' => {
          'status_updated_at' => status_update_time
        },
        'flexifield' => {},
        'subscriptions' => {},
        'schema_less_ticket' => {
          'long_tc02' => Faker::Number.number(3),
          'string_tc03' => email,
          'to_emails' => [Faker::Internet.email, Faker::Internet.email]
        }
      }
    }.merge!(custom_hash)
    Helpdesk::ArchiveTicket.any_instance.stubs(:archive_ticket_association).returns(Helpdesk::ArchiveTicketAssociation.new(association_data: ticket_stub_hash))
  end

  def test_fetch_contractor_tickets_with_requester_id
    enable_archive_tickets do
      begin
        create_archive_ticket_with_assoc
        archive_test_ticket = @account.archive_tickets.last
        fetched_ticket = @account.archive_tickets.contractor_tickets(archive_test_ticket.requester_id, nil, 'or').last
        assert_equal archive_test_ticket, fetched_ticket
      ensure
        archive_test_ticket.destroy if archive_test_ticket.present?
      end
    end
  end

  def test_fetch_contractor_tickets_with_company_id
    company = create_company
    enable_archive_tickets do
      begin
        create_archive_ticket_with_assoc(company_id: company.id)
        archive_test_ticket = @account.archive_tickets.last
        fetched_ticket = @account.archive_tickets.contractor_tickets(nil, company.id, 'or').last
        assert_equal archive_test_ticket, fetched_ticket
      ensure
        archive_test_ticket.destroy if archive_test_ticket.present?
      end
    end
  end

  def test_archive_ticket_sort_fields
    enable_archive_tickets do
      begin
        create_archive_ticket_with_assoc
        archive_test_ticket = @account.archive_tickets.last
        assert_includes @account.archive_tickets.sort_fields_options, ['Date Created', :created_at]
        assert_includes @account.archive_tickets.sort_fields_options_array, :created_at
      ensure
        archive_test_ticket.destroy if archive_test_ticket.present?
      end
    end
  end

  def test_archive_ticket_params
    enable_archive_tickets do
      begin
        email = Faker::Internet.email
        status_update_time = Time.zone.now
        create_custom_field(Faker::Lorem.word, 'text')
        create_archive_ticket_with_assoc
        ticket_association_s3_stub(email, status_update_time)
        archive_test_ticket = @account.archive_tickets.last
        assert_equal archive_test_ticket.freshness, :reply
        assert_equal archive_test_ticket.priority_key, :medium
        assert_nil archive_test_ticket.is_fb_message?
        assert_nil archive_test_ticket.is_fb_wall_post?
        assert_nil archive_test_ticket.is_fb_comment?
        assert_equal archive_test_ticket.chat?, false
        assert_empty archive_test_ticket.all_attachments
        assert_empty archive_test_ticket.conversation(1, 5, [1])
        assert_empty archive_test_ticket.conversation_since(archive_test_ticket.created_at)
        assert_empty archive_test_ticket.conversation_before(archive_test_ticket.created_at)
        assert_equal archive_test_ticket.conversation_count, 0
        assert_includes archive_test_ticket.ticket_cc, email
        assert archive_test_ticket.non_text_custom_field
        assert_equal archive_test_ticket.requester_info, archive_test_ticket.requester.email
        assert_equal archive_test_ticket.requester_name, archive_test_ticket.requester.name
        assert archive_test_ticket.included_in_cc?(email)
        assert_equal archive_test_ticket.product_name, 'No Product'
        assert_equal archive_test_ticket.company_name, 'No company'
        assert_equal archive_test_ticket.included_in_to_emails?(email), false
        assert archive_test_ticket.to_liquid
        assert_equal archive_test_ticket.status_updated_at, status_update_time
        assert_empty archive_test_ticket.flexifield_data
        assert_empty archive_test_ticket.subscription_data
        assert_equal archive_test_ticket.to_param, archive_test_ticket.display_id.to_s
        assert_equal archive_test_ticket.portal_host, @account.host
        assert_nil archive_test_ticket.description_with_attachments
        assert archive_test_ticket.encode_display_id
        assert_equal archive_test_ticket.ticket_id_delimiter, '#'
        assert_equal archive_test_ticket.requester_status_name, 'This ticket has been Closed'
        assert_equal archive_test_ticket.sender_email, email
        assert_equal archive_test_ticket.url_protocol, 'https'
        assert_includes archive_test_ticket.support_ticket_path, "support/tickets/archived/#{archive_test_ticket.display_id}"
        assert_equal archive_test_ticket.from_email, email
        assert archive_test_ticket.customer_performed?(archive_test_ticket.requester)
        assert_equal archive_test_ticket.agent_as_requester?(archive_test_ticket.requester.id), false
        assert_equal archive_test_ticket.agent_performed?(archive_test_ticket.requester), false
        assert_equal archive_test_ticket.accessible_in_helpdesk?(archive_test_ticket.requester), false
        assert_equal archive_test_ticket.restricted_in_helpdesk?(archive_test_ticket.requester), false
        assert_equal archive_test_ticket.group_agent_accessible?(archive_test_ticket.requester), false
        assert_empty archive_test_ticket.public_notes
      ensure
        archive_test_ticket.destroy if archive_test_ticket.present?
        Helpdesk::ArchiveTicket.any_instance.unstub(:archive_ticket_association)
      end
    end
  end

  def test_ticket_fetch_based_on_created_at_returns_correct_value
    enable_archive_tickets do
      begin
        create_archive_ticket_with_assoc
        archive_test_ticket = @account.archive_tickets.last
        fetched_ticket = @account.archive_tickets.created_at_inside(archive_test_ticket.created_at, archive_test_ticket.created_at).last
        assert_equal archive_test_ticket, fetched_ticket
      ensure
        archive_test_ticket.destroy if archive_test_ticket.present?
      end
    end
  end

  def test_ticket_fetch_based_on_user_with_group_ticket_permission
    user = add_test_agent(@account, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
    Agent.any_instance.stubs(:ticket_permission).returns(Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
    enable_archive_tickets do
      begin
        create_archive_ticket_with_assoc(requester_id: user.id)
        archive_test_ticket = @account.archive_tickets.last
        fetched_requester = @account.archive_tickets.permissible_condition(user).last
        assert_equal archive_test_ticket.requester_id, fetched_requester
      ensure
        archive_test_ticket.destroy if archive_test_ticket.present?
      end
    end
  end

  def test_ticket_fetch_based_on_user_with_assigned_tickets_ticket_permission
    user = add_test_agent(@account, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])
    Agent.any_instance.stubs(:ticket_permission).returns(Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])
    enable_archive_tickets do
      begin
        create_archive_ticket_with_assoc(requester_id: user.id)
        archive_test_ticket = @account.archive_tickets.last
        @account.reload
        fetched_requester = @account.archive_tickets.permissible_condition(user).last
        assert_equal archive_test_ticket.requester_id, fetched_requester
      ensure
        archive_test_ticket.destroy if archive_test_ticket.present?
      end
    end
  end

  def test_ticket_json_format
    enable_archive_tickets do
      begin
        email = Faker::Internet.email
        status_update_time = Time.zone.now
        create_archive_ticket_with_assoc
        archive_test_ticket = @account.archive_tickets.last
        ticket_association_s3_stub(email, status_update_time)
        assert archive_test_ticket.as_json
      ensure
        archive_test_ticket.destroy if archive_test_ticket.present?
      end
    end
  end

  def test_ticket_json_basic_format
    enable_archive_tickets do
      begin
        email = Faker::Internet.email
        status_update_time = Time.zone.now
        create_archive_ticket_with_assoc
        archive_test_ticket = @account.archive_tickets.last
        ticket_association_s3_stub(email, status_update_time)
        assert archive_test_ticket.as_json(basic: true)
      ensure
        archive_test_ticket.destroy if archive_test_ticket.present?
      end
    end
  end

  def test_ticket_xml_format
    enable_archive_tickets do
      begin
        email = Faker::Internet.email
        status_update_time = Time.zone.now
        create_dependent_custom_field(%w[test_custom_country test_custom_state test_custom_city])
        create_archive_ticket_with_assoc
        archive_test_ticket = @account.archive_tickets.last
        ticket_association_s3_stub(email, status_update_time)
        assert archive_test_ticket.to_xml(skip_instruct: true)
      ensure
        archive_test_ticket.destroy if archive_test_ticket.present?
      end
    end
  end

  def test_ticket_xml_basic_format
    enable_archive_tickets do
      begin
        email = Faker::Internet.email
        status_update_time = Time.zone.now
        create_archive_ticket_with_assoc
        archive_test_ticket = @account.archive_tickets.last
        ticket_association_s3_stub(email, status_update_time)
        assert archive_test_ticket.to_xml(basic: true, skip_instruct: true)
      ensure
        archive_test_ticket.destroy if archive_test_ticket.present?
      end
    end
  end

  def test_archive_ticket_from_outbound_email
    enable_archive_tickets do
      begin
        Account.any_instance.stubs(:compose_email_enabled?).returns(true)
        email = Faker::Internet.email
        status_update_time = Time.zone.now
        create_archive_ticket_with_assoc(source: 10)
        archive_test_ticket = @account.archive_tickets.last
        ticket_association_s3_stub(email, status_update_time)
        assert_equal archive_test_ticket.outbound_initiator, @agent
      ensure
        archive_test_ticket.destroy if archive_test_ticket.present?
        Account.any_instance.unstub(:compose_email_enabled?)
      end
    end
  end

  def test_outbound_initiator_raises_exception
    enable_archive_tickets do
      begin
        Account.any_instance.stubs(:compose_email_enabled?).returns(true)
        create_archive_ticket_with_assoc(source: 10)
        archive_test_ticket = @account.archive_tickets.last
        YAML.stubs(:load).raises(ArgumentError)
        assert_equal archive_test_ticket.outbound_initiator, archive_test_ticket.requester
      ensure
        archive_test_ticket.destroy if archive_test_ticket.present?
        Account.any_instance.unstub(:compose_email_enabled?)
        YAML.unstub(:load)
      end
    end
  end

  def test_outbound_initiator_without_archive_notes
    enable_archive_tickets do
      begin
        Account.any_instance.stubs(:compose_email_enabled?).returns(true)
        create_archive_ticket_with_assoc(source: 10)
        archive_test_ticket = @account.archive_tickets.last
        archive_test_ticket.archive_notes.stubs(:find_by_source).returns(nil)
        assert_equal archive_test_ticket.outbound_initiator, archive_test_ticket.requester
      ensure
        archive_test_ticket.destroy if archive_test_ticket.present?
        Account.any_instance.unstub(:compose_email_enabled?)
        Helpdesk::ArchiveTicket.any_instance.unstub(:archive_notes)
      end
    end
  end

  def test_archive_ticket_public_notes_with_shard_value
    enable_archive_tickets do
      begin
        create_archive_ticket_with_assoc
        archive_test_ticket = @account.archive_tickets.last
        ActiveRecordShards::ShardSelection.any_instance.stubs(:shard).returns('shard_1')
        archive_test_ticket.stubs(:id).returns(1)
        assert_empty archive_test_ticket.public_notes
      ensure
        archive_test_ticket.destroy if archive_test_ticket.present?
      end
    end
  end

  def test_archive_ticket_esv2_json_spam_with_integer_returns_boolean_value
    enable_archive_tickets do
      begin
        create_archive_ticket_with_assoc
        archive_test_ticket = @account.archive_tickets.last
        email = Faker::Internet.email
        status_update_time = Time.zone.now
        custom_hash = {
          'helpdesk_tickets' => {
            'spam' => 0
          }
        }
        ticket_association_s3_stub(email, status_update_time, custom_hash)
        assert_equal JSON.parse(archive_test_ticket.to_esv2_json)['spam'], false
      ensure
        archive_test_ticket.destroy if archive_test_ticket.present?
        Helpdesk::ArchiveTicket.any_instance.unstub(:archive_ticket_association)
      end
    end
  end

  def test_archive_ticket_esv2_json_spam_with_boolean_returns_original_value
    enable_archive_tickets do
      begin
        create_archive_ticket_with_assoc
        archive_test_ticket = @account.archive_tickets.last
        email = Faker::Internet.email
        status_update_time = Time.zone.now
        custom_hash = {
          'helpdesk_tickets' => {
            'spam' => true
          }
        }
        ticket_association_s3_stub(email, status_update_time, custom_hash)
        assert_equal JSON.parse(archive_test_ticket.to_esv2_json)['spam'], true
      ensure
        archive_test_ticket.destroy if archive_test_ticket.present?
        Helpdesk::ArchiveTicket.any_instance.unstub(:archive_ticket_association)
      end
    end
  end

  def test_archive_ticket_esv2_json_spam_with_nil_returns_original_value
    enable_archive_tickets do
      begin
        create_archive_ticket_with_assoc
        archive_test_ticket = @account.archive_tickets.last
        email = Faker::Internet.email
        status_update_time = Time.zone.now
        custom_hash = {
          'helpdesk_tickets' => {
            'spam' => nil
          }
        }
        ticket_association_s3_stub(email, status_update_time, custom_hash)
        assert_equal JSON.parse(archive_test_ticket.to_esv2_json)['spam'], nil
      ensure
        archive_test_ticket.destroy if archive_test_ticket.present?
        Helpdesk::ArchiveTicket.any_instance.unstub(:archive_ticket_association)
      end
    end
  end

  def test_archive_ticket_esv2_json_boolean_flexifields_with_boolean_returns_original_value
    email = Faker::Internet.email
    status_update_time = Time.zone.now
    @account.rollback(:custom_fields_search)
    enable_archive_tickets do
      begin
        create_archive_ticket_with_assoc
        archive_test_ticket = @account.archive_tickets.last
        custom_hash = {
          'helpdesk_tickets_association' => {
            'flexifield' => {
              'ff_boolean01' => false
            },
            'ticket_states' => {
              'status_updated_at' => status_update_time
            },
            'subscriptions' => {},
            'schema_less_ticket' => {
              'long_tc02' => Faker::Number.number(3),
              'string_tc03' => email,
              'to_emails' => [Faker::Internet.email, Faker::Internet.email]
            }
          }
        }
        ticket_association_s3_stub(email, status_update_time, custom_hash)
        assert_equal JSON.parse(archive_test_ticket.to_esv2_json)['ff_boolean01'], false
      ensure
        archive_test_ticket.destroy if archive_test_ticket.present?
        Helpdesk::ArchiveTicket.any_instance.unstub(:archive_ticket_association)
      end
    end
  end

  def test_archive_ticket_esv2_json_boolean_flexifields_with_integer_returns_boolean_value
    @account.rollback(:custom_fields_search)
    email = Faker::Internet.email
    status_update_time = Time.zone.now
    enable_archive_tickets do
      begin
        create_archive_ticket_with_assoc
        archive_test_ticket = @account.archive_tickets.last
        custom_hash = {
          'helpdesk_tickets_association' => {
            'flexifield' => {
              'ff_boolean01' => 1
            },
            'ticket_states' => {
              'status_updated_at' => status_update_time
            },
            'subscriptions' => {},
            'schema_less_ticket' => {
              'long_tc02' => Faker::Number.number(3),
              'string_tc03' => email,
              'to_emails' => [Faker::Internet.email, Faker::Internet.email]
            }
          }
        }
        ticket_association_s3_stub(email, status_update_time, custom_hash)
        assert_equal JSON.parse(archive_test_ticket.to_esv2_json)['ff_boolean01'], true
      ensure
        archive_test_ticket.destroy if archive_test_ticket.present?
        Helpdesk::ArchiveTicket.any_instance.unstub(:archive_ticket_association)
      end
    end
  end

  def test_archive_ticket_esv2_json_boolean_flexifields_with_nil_returns_original_value
    @account.rollback(:custom_fields_search)
    email = Faker::Internet.email
    status_update_time = Time.zone.now
    enable_archive_tickets do
      begin
        create_archive_ticket_with_assoc
        archive_test_ticket = @account.archive_tickets.last
        custom_hash = {
          'helpdesk_tickets_association' => {
            'flexifield' => {
              'ff_boolean01' => nil
            },
            'ticket_states' => {
              'status_updated_at' => status_update_time
            },
            'subscriptions' => {},
            'schema_less_ticket' => {
              'long_tc02' => Faker::Number.number(3),
              'string_tc03' => email,
              'to_emails' => [Faker::Internet.email, Faker::Internet.email]
            }
          }
        }
        ticket_association_s3_stub(email, status_update_time, custom_hash)
        assert_equal JSON.parse(archive_test_ticket.to_esv2_json)['ff_boolean01'], nil
      ensure
        archive_test_ticket.destroy if archive_test_ticket.present?
        Helpdesk::ArchiveTicket.any_instance.unstub(:archive_ticket_association)
      end
    end
  end

  def test_resolution_status_and_first_response_status_for_service_task
    @account.add_feature(:field_service_management)
    enable_archive_tickets do
      begin
        perform_fsm_operations
        fsm_ticket = create_service_task_ticket
        convert_ticket_to_archive(fsm_ticket)
        assert_equal '', fsm_ticket.resolution_status
        assert_equal '', fsm_ticket.first_response_status
      ensure
        fsm_ticket.destroy
        cleanup_fsm
        @account.revoke_feature(:field_service_management)
      end
    end
  end

  def test_archive_ticket_esv2_json_non_boolean_flexifields_with_integer_returns_original_value
    @account.rollback(:custom_fields_search)
    email = Faker::Internet.email
    status_update_time = Time.zone.now
    enable_archive_tickets do
      begin
        create_archive_ticket_with_assoc
        archive_test_ticket = @account.archive_tickets.last
        custom_hash = {
          'helpdesk_tickets_association' => {
            'flexifield' => {
              'ff_int01' => 1
            },
            'ticket_states' => {
              'status_updated_at' => status_update_time
            },
            'subscriptions' => {},
            'schema_less_ticket' => {
              'long_tc02' => Faker::Number.number(3),
              'string_tc03' => email,
              'to_emails' => [Faker::Internet.email, Faker::Internet.email]
            }
          }
        }
        ticket_association_s3_stub(email, status_update_time, custom_hash)
        assert_equal JSON.parse(archive_test_ticket.to_esv2_json)['ff_int01'], 1
      ensure
        archive_test_ticket.destroy if archive_test_ticket.present?
        Helpdesk::ArchiveTicket.any_instance.unstub(:archive_ticket_association)
      end
    end
  end
end
