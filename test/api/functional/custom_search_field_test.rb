require_relative '../unit_test_helper'
require Rails.root.join('test', 'api', 'helpers', 'ticket_fields_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'groups_test_helper.rb')
require Rails.root.join('spec', 'support', 'agent_helper.rb')
require Rails.root.join('spec', 'support', 'ticket_helper.rb')

class CustomSearchFieldTest < ActionView::TestCase
  include TicketFieldsTestHelper
  include AgentHelper
  include GroupsTestHelper
  include TicketHelper

  CUSTOM_FIELDS = %w[text paragraph].freeze

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_custom_fields_with_ffs
    create_custom_field_search false
    ticket = initial_setup
    ticket.custom_field = { "test_custom_text_#{@account.id}": 'Single line', "test_custom_paragraph_#{@account.id}": 'Multine line' }
    ticket.save!
    ticket.reload
    @model_changes = ticket.model_changes
    Account.any_instance.stubs(:launched?).returns(false)
    val = ActiveSupport::JSON.decode(ticket.to_esv2_json)
    assert_not_equal('Single line', val['custom_single_line_texts'])
    assert_equal(false, ticket.esv2_fields_updated?)
    Account.any_instance.unstub(:launched?)
  end

  def test_custom_fields_with_dn
    create_custom_field_search true
    ticket = initial_setup
    ticket.send("test_custom_text_#{@account.id}=", 'Single line')
    ticket.save!
    ticket.reload
    @model_changes = ticket.model_changes
    Account.any_instance.stubs(:launched?).returns(true)
    val = ActiveSupport::JSON.decode(ticket.to_esv2_json)
    assert_equal('Single line', val['custom_single_line_texts'][0])
    assert_equal(false, ticket.esv2_fields_updated?)
    Account.any_instance.unstub(:launched?)
  end

  private

  def initial_setup
    group = create_group @account
    agent = @account.agents.first
    ticket = create_ticket(params = { requester_id: agent.user_id, priority: 4, subject: 'Test ticket' }, group)
    ticket
  end

  def create_custom_field_search(denorm)
    CUSTOM_FIELDS.each do |custom_field|
      if denorm
        create_custom_field_dn("test_custom_#{custom_field}", custom_field)
      else
        create_custom_field("test_custom_#{custom_field}", custom_field)
      end
    end
  end
end
