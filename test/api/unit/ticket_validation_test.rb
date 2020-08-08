require_relative '../unit_test_helper'
require "#{Rails.root}/test/api/helpers/custom_field_validator_test_helper.rb"

class TicketValidationTest < ActionView::TestCase
  def teardown
    Account.unstub(:current)
    super
  end

  def statuses
    statuses  = []
    (2...7).map do |x|
      h = Helpdesk::TicketStatus.new
      h.status_id = x
      h.stop_sla_timer = true if [3, 4, 5, 6].include?(x)
      statuses << h
    end
    statuses
  end

  def test_mandatory
    Account.stubs(:current).returns(Account.first)
    controller_params = { requester_id: 1, description: Faker::Lorem.paragraph,  ticket_fields: [], statuses: statuses }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    assert ticket.valid?(:create)
    Account.unstub(:current)
  end

  def test_placeholder_validation
    Account.stubs(:current).returns(Account.first)
    controller_params = { template_text: 'test' }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    assert ticket.valid?(:parse_template)
    ticket = TicketValidation.new({}, item)
    refute ticket.valid?(:parse_template)
    errors = ticket.errors.full_messages
    assert errors.include?('Template text datatype_mismatch')
    Account.unstub(:current)
  end

  def test_email_validation
    Account.stubs(:current).returns(Account.first)
    controller_params = { 'email' => 'fggg,ss@fff.com',  ticket_fields: [], statuses: statuses  }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?
    errors = ticket.errors.full_messages
    assert errors.include?('Email invalid_format')
    assert_equal({ email: { accepted: :'valid email address' } }, ticket.error_options)
    Account.unstub(:current)
  end

  def test_cc_emails_validation
    Account.stubs(:current).returns(Account.first)
    controller_params = { ticket_fields: [], 'email' => 'fgggss@fff.com', 'cc_emails' => ['werewrwe@ddd.com, sdfsfdsf@ddd.com'], statuses: statuses }
    item = nil,
           ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?
    errors = ticket.errors.full_messages
    assert errors.include?('Cc emails array_invalid_format')
    assert_equal({ email: {}, cc_emails: { accepted: :'valid email address' } }, ticket.error_options)
    Account.unstub(:current)
  end

    def test_cc_emails_validation_non_english
    Account.stubs(:current).returns(Account.first)
    controller_params = { ticket_fields: [], 'email' => 'fgggss@fff.com', 'cc_emails' => ['Бургер Кинг<adgasg@fff.com>', 'ÒÂÅÎÏÍÍÅ<adgasg@fff.com>'], statuses: statuses }
    item = nil,
           ticket = TicketValidation.new(controller_params, item)
    assert ticket.valid?
    Account.unstub(:current)
  end

  def test_tags_comma_invalid
    Account.stubs(:current).returns(Account.first)
    controller_params = { 'requester_id' => 1, ticket_fields: [], tags: ['comma,test'], statuses: statuses }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?(:create)
    errors = ticket.errors.full_messages
    assert errors.include?('Tags special_chars_present')
    assert_equal({ requester_id: {}, tags: { chars: ',' } }, ticket.error_options)
    Account.unstub(:current)
  end

  def test_tags_comma_valid
    Account.stubs(:current).returns(Account.first)
    controller_params = { 'requester_id' => 1, description: Faker::Lorem.paragraph,  ticket_fields: [], tags: ['comma', 'test'], statuses: statuses }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    assert ticket.valid?(:create)
    Account.unstub(:current)
  end

  def test_internal_groups_and_agents_valid
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:shared_ownership_enabled?).returns(true)
    controller_params = { status: 6 , internal_group_id: 3 , internal_agent_id: 5 , ticket_fields: [] , statuses: statuses , requester_id: 1}
    item = nil
    ticket = TicketValidation.new(controller_params , item)
    assert ticket.valid?(:create)
    Account.any_instance.unstub(:shared_ownership_enabled?)
    Account.unstub(:current)
  end

  def test_internal_groups_and_agents_invalid
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:shared_ownership_enabled?).returns(true)
    controller_params = { status: 6 , internal_group_id: "five" , internal_agent_id: "three" , ticket_fields: [] , statuses: statuses , requester_id: 1}
    item = nil
    ticket = TicketValidation.new(controller_params , item)
    refute ticket.valid?(:create)
    errors = ticket.errors.full_messages
    assert errors.include?("Internal group datatype_mismatch")
    assert errors.include?("Internal agent datatype_mismatch")
    Account.any_instance.unstub(:shared_ownership_enabled?)
    Account.unstub(:current)
  end

  def test_valid_params_when_shared_ownership_enabled
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:shared_ownership_enabled?).returns(true)
    controller_params = { internal_group_id: 3 , internal_agent_id: 5 , ticket_fields: [] , statuses: statuses , requester_id: 1}
    item = nil
    ticket = TicketValidation.new(controller_params , item)
    assert ticket.valid?(:create)
    Account.any_instance.unstub(:shared_ownership_enabled?)
    Account.unstub(:current)
  end

  def test_valid_params_when_shared_ownership_not_enabled
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:shared_ownership_enabled?).returns(false)
    controller_params = { internal_group_id: 3 ,ticket_fields: [] , statuses: statuses , requester_id: 1, description: Faker::Lorem.paragraph}
    item = Helpdesk::Ticket.new
    ticket = TicketValidation.new(controller_params , item)
    refute ticket.valid?(:update)
    errors = ticket.errors.full_messages
    Account.any_instance.unstub(:shared_ownership_enabled?)
    Account.unstub(:current)
  end

  def test_invalid_group_params_when_shared_ownership_enabled
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:shared_ownership_enabled?).returns(false)
    controller_params = { internal_group_id: 0 ,ticket_fields: [] , statuses: statuses , requester_id: 1, description: Faker::Lorem.paragraph}
    item = Helpdesk::Ticket.new
    ticket = TicketValidation.new(controller_params , item)
    refute ticket.valid?(:update)
    errors = ticket.errors.full_messages
    Account.any_instance.unstub(:shared_ownership_enabled?)
    Account.unstub(:current)
  end

  def test_invalid_agent_params_when_shared_ownership_enabled
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:shared_ownership_enabled?).returns(false)
    controller_params = { internal_agent_id: 0 ,ticket_fields: [] , statuses: statuses , requester_id: 1, description: Faker::Lorem.paragraph}
    item = Helpdesk::Ticket.new
    ticket = TicketValidation.new(controller_params , item)
    refute ticket.valid?(:update)
    errors = ticket.errors.full_messages
    Account.any_instance.unstub(:shared_ownership_enabled?)
    Account.unstub(:current)
  end
  def test_attachment_multiple_errors
    Account.stubs(:current).returns(Account.first)
    String.any_instance.stubs(:size).returns(20_000_000)
    TicketsValidationHelper.stubs(:attachment_size).returns(100)
    controller_params = { requester_id: 1, description: Faker::Lorem.paragraph, ticket_fields: [], attachments: ['file.png'], statuses: statuses }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?(:create)
    errors = ticket.errors.full_messages
    assert errors.include?('Attachments array_datatype_mismatch')
    assert_equal({ requester_id: {}, description: {}, attachments: { expected_data_type: 'valid file format' } }, ticket.error_options)
    assert errors.count == 1
    Account.unstub(:current)
    TicketsValidationHelper.unstub(:attachment_size)
  end

  def test_tags_multiple_errors
    Account.stubs(:current).returns(Account.first)
    controller_params = { 'requester_id' => 1, description: Faker::Lorem.paragraph,  ticket_fields: [], tags: 'comma,test', statuses: statuses }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?(:create)
    errors = ticket.errors.full_messages
    assert errors.include?('Tags datatype_mismatch')
    assert_equal({ requester_id: {}, description: {}, tags: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: String } }, ticket.error_options)
    Account.unstub(:current)
  end

  def test_custom_fields_multiple_errors
    Account.stubs(:current).returns(Account.first)
    TicketsValidationHelper.stubs(:data_type_validatable_custom_fields).returns(CustomFieldValidatorTestHelper.data_type_validatable_custom_fields)
    controller_params = { 'requester_id' => 1, description: Faker::Lorem.paragraph,  ticket_fields: [], custom_fields: 'number1_1 = uioo', statuses: statuses }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?(:create)
    errors = ticket.errors.full_messages
    assert errors.include?('Custom fields datatype_mismatch')
    assert_equal({ requester_id: {}, description: {}, custom_fields: { expected_data_type: 'key/value pair', prepend_msg: :input_received, given_data_type: String } }, ticket.error_options)
    TicketsValidationHelper.unstub(:data_type_validatable_custom_fields)
    Account.unstub(:current)
  end

  def test_fr_due_by_nil_and_due_by_nil_when_status_is_open
    Account.stubs(:current).returns(Account.first)
    controller_params = { requester_id: 1,  description: Faker::Lorem.paragraph,  ticket_fields: [], statuses: statuses, status: 2, due_by: nil, fr_due_by: nil }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    assert ticket.valid?(:create)
    Account.unstub(:current)
  end

  def test_fr_due_by_not_nil_and_due_by_not_nil_when_status_is_closed
    Account.stubs(:current).returns(Account.first)
    controller_params = { requester_id: 1,  description: Faker::Lorem.paragraph,  ticket_fields: [], statuses: statuses, status: 5, due_by: '', fr_due_by: '' }.with_indifferent_access
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?(:create)
    errors = ticket.errors.full_messages
    assert errors.include?('Due by cannot_set_due_by_fields')
    assert errors.include?('Fr due by cannot_set_due_by_fields')
    assert_equal({ status: {}, requester_id: {}, description: {}, fr_due_by: { code: :incompatible_field },
                   due_by: { code: :incompatible_field } }, ticket.error_options)
    Account.unstub(:current)
  end

  def test_status_priority_source_invalid
    Account.stubs(:current).returns(Account.first)
    controller_params = { status: true, priority: true, source: true, statuses: statuses, ticket_fields: [] }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?(:create)
    errors = ticket.errors.full_messages
    assert errors.include?('Status not_included')
    assert errors.include?('Priority not_included')
    assert errors.include?('Source not_included')

    controller_params = { status: '2', priority: '2', source: '', statuses: statuses, ticket_fields: [] }
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?(:create)
    errors = ticket.errors.full_messages
    assert errors.include?('Status not_included')
    assert errors.include?('Priority not_included')
    assert errors.include?('Source not_included')
  ensure
    Account.unstub(:current)
  end

  def test_complex_fields_with_nil
    Account.stubs(:current).returns(Account.first)
    controller_params = { 'requester_id' => 1, description: Faker::Lorem.paragraph, statuses: statuses,  ticket_fields: [], cc_emails: nil, tags: nil, custom_fields: nil, attachments: nil }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?(:create)
    errors = ticket.errors.full_messages
    assert errors.include?('Tags datatype_mismatch')
    assert errors.include?('Custom fields datatype_mismatch')
    assert errors.include?('Cc emails datatype_mismatch')
    assert errors.include?('Attachments blank')
    assert_equal({ requester_id: {}, description: {}, attachments: {}, cc_emails: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: 'Null'  },
                   tags: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: 'Null'  },
                   custom_fields: { expected_data_type: 'key/value pair', prepend_msg: :input_received, given_data_type: 'Null'  } }, ticket.error_options)
    Account.unstub(:current)
  end

  def test_description
    Account.stubs(:current).returns(Account.first)
    desc_field = Helpdesk::TicketField.new
    desc_field.stubs(:required).returns(true)
    desc_field.stubs(:default).returns(true)
    desc_field.stubs(:name).returns('description')
    controller_params = { 'requester_id' => 1, ticket_fields: [desc_field], statuses: statuses }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?(:create)
    assert ticket.errors.full_messages.include?('Description datatype_mismatch')
    assert_equal({ description: {  expected_data_type: String, code: :missing_field }, requester_id: {} }, ticket.error_options)

    controller_params = { 'requester_id' => 1, ticket_fields: [desc_field], description: '', statuses: statuses }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?(:create)
    assert ticket.errors.full_messages.include?('Description blank')
    assert_equal({ requester_id: {}, description: { expected_data_type: String } }, ticket.error_options)

    controller_params = { 'requester_id' => 1, ticket_fields: [desc_field], statuses: statuses }
    item = Helpdesk::Ticket.new
    item.build_ticket_body
    item.ticket_body.description = ''
    item.ticket_body.description_html = 'test'
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?(:update)
    refute ticket.errors.full_messages.include?('Description blank')

    controller_params = { 'requester_id' => 1, ticket_fields: [desc_field], description: true, statuses: statuses }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?(:create)
    assert ticket.errors.full_messages.include?('Description datatype_mismatch')
    assert_equal({ requester_id: {}, description: { expected_data_type: String, prepend_msg: :input_received,
                                                    given_data_type: 'Boolean' } }, ticket.error_options)
    Account.unstub(:current)
  end

  def test_outbound_ticket_update
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:compose_email_enabled?).returns(true)
    controller_params = {  'subject' => Faker::Lorem.paragraph, 'description' => Faker::Lorem.paragraph,  ticket_fields: [], statuses: statuses }
    item = Helpdesk::Ticket.new(requester_id: 1, status: 2, priority: 3, source: 10)
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?(:update)
    errors = ticket.errors.full_messages
    assert errors.include?('Subject outbound_email_field_restriction')
    assert errors.include?('Description outbound_email_field_restriction')
  ensure
    Account.any_instance.unstub(:compose_email_enabled?)
    Account.unstub(:current)
  end

  def test_bulk_update_validation
    Account.stubs(:current).returns(Account.first)
    controller_params = {  'description' => Faker::Lorem.paragraph, ticket_fields: [], custom_fields: 'Incorrect_value' }
    ticket = TicketValidation.new(controller_params, nil)
    ticket.skip_bulk_validations = true
    refute ticket.valid?(:bulk_update)
    errors = ticket.errors.full_messages
    assert errors.include?('Custom fields datatype_mismatch')
    assert_equal({ description: {}, custom_fields: { expected_data_type: 'key/value pair', prepend_msg: :input_received, given_data_type: String } }, ticket.error_options)
    Account.unstub(:current)
  end

  def test_validate_cloud_files
    Account.stubs(:current).returns(Account.first)
    controller_params = { 'requester_id' => 1, 'subject' => Faker::Lorem.paragraph,'description' => Faker::Lorem.paragraph,
                           ticket_fields: [], statuses: statuses, 'cloud_files' => Faker::Lorem.word }
    tkt_validation = TicketValidation.new(controller_params, nil)
    refute tkt_validation.valid?
    errors = tkt_validation.errors.full_messages
    assert errors.include?('Cloud files datatype_mismatch')

    controller_params = { 'requester_id' => 1, 'subject' => Faker::Lorem.paragraph,'description' => Faker::Lorem.paragraph,
                           ticket_fields: [], statuses: statuses, 'cloud_files' => [{'filename' => Faker::Lorem.word}] }
    tkt_validation = TicketValidation.new(controller_params, nil)
    refute tkt_validation.valid?
    errors = tkt_validation.errors.full_messages
    assert errors.include?('Cloud files is invalid')
    Account.unstub(:current)
  end

  def test_skip_notification_validation
    Account.stubs(:current).returns(Account.first)
    item = Helpdesk::Ticket.new(requester_id: 1, status: 2, priority: 3, source: 10)
    controller_params = { status: 3, statuses: statuses, ticket_fields: [], 'skip_close_notification' => true }
    ticket_validation = TicketValidation.new(controller_params, item)
    refute ticket_validation.valid?(:update)
    errors = ticket_validation.errors.full_messages
    assert errors.include?('Skip close notification cannot_set_skip_notification')

    controller_params = { status: 5, statuses: statuses, ticket_fields: [], 'skip_close_notification' => true }
    ticket_validation = TicketValidation.new(controller_params, item)
    assert ticket_validation.valid?(:update)
    Account.unstub(:current)
  end

  def test_valid_skill_without_feature
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:skill_based_round_robin_enabled?).returns(false)
    User.stubs(:current).returns(User.new)
    controller_params = { 'ticket_fields' => [], 'skill_id' => 1 }
    ticket = TicketValidation.new(controller_params, nil)
    ticket.skip_bulk_validations = true
    refute ticket.valid?(:bulk_update)
    errors = ticket.errors.full_messages
    assert errors.include?('Skill require_feature_for_attribute')
    User.unstub(:current)
    Account.any_instance.unstub(:skill_based_round_robin_enabled?)
    Account.unstub(:current)
  end

  def test_valid_skill_without_privilege
    Account.stubs(:current).returns(Account.first)
    Account.current.stubs(:skill_based_round_robin_enabled?).returns(true)
    User.stubs(:current).returns(User.new)
    User.current.stubs(:privilege?).with(:edit_ticket_skill).returns(false)
    controller_params = { 'ticket_fields' => [], 'skill_id' => 1 }
    ticket = TicketValidation.new(controller_params, nil)
    ticket.skip_bulk_validations = true
    refute ticket.valid?(:bulk_update)
    errors = ticket.errors.full_messages
    assert errors.include?('Skill no_edit_ticket_skill_privilege')
    User.current.unstub(:privilege?)
    User.unstub(:current)
    Account.current.unstub(:skill_based_round_robin_enabled?)
    Account.unstub(:current)
  end

  def test_invalid_skill_with_privilege
    Account.stubs(:current).returns(Account.first)
    Account.current.stubs(:skill_based_round_robin_enabled?).returns(true)
    User.stubs(:current).returns(User.new)
    User.current.stubs(:privilege?).with(:edit_ticket_skill).returns(true)
    controller_params = { 'ticket_fields' => [], 'skill_id' => 'test' }
    ticket = TicketValidation.new(controller_params, nil)
    ticket.skip_bulk_validations = true
    refute ticket.valid?(:bulk_update)
    errors = ticket.errors.full_messages
    assert errors.include?('Skill datatype_mismatch')
    User.current.unstub(:privilege?)
    User.unstub(:current)
    Account.current.unstub(:skill_based_round_robin_enabled?)
    Account.unstub(:current)
  end

  def test_valid_skill_with_privilege
    Account.stubs(:current).returns(Account.first)
    Account.current.stubs(:skill_based_round_robin_enabled?).returns(true)
    User.stubs(:current).returns(User.new)
    User.current.stubs(:privilege?).with(:edit_ticket_skill).returns(true)
    controller_params = { 'ticket_fields' => [], 'skill_id' => 1 }
    ticket = TicketValidation.new(controller_params, nil)
    ticket.skip_bulk_validations = true
    assert ticket.valid?(:bulk_update)
    User.current.unstub(:privilege?)
    User.unstub(:current)
    Account.current.unstub(:skill_based_round_robin_enabled?)
    Account.unstub(:current)
  end

end