require_relative '../../test_helper'
require_relative '../../api/helpers/test_class_methods.rb'
['user_helper.rb', 'ticket_helper.rb'].each { |file| require Rails.root.join('spec', 'support', file) }
class TicketBodyTest < ActiveSupport::TestCase
  include UsersHelper
  include TicketHelper

  def setup
    super
    @account = create_test_account if @account.nil?
    Account.stubs(:current).returns(@account)
    @description_html = '<div>hello MasterCard  5500 0000 0000 0004</div>'
    @redacted_description = 'hello MasterCard  XXXX XXXX XXXX 0004'
    Account.any_instance.stubs(:redaction_enabled?).returns(true)
    AccountAdditionalSettings.any_instance.stubs(:redaction).returns(credit_card_number: true)
  end

  def teardown
    Account.unstub(:current)
    Account.any_instance.unstub(:redaction_enabled?)
    Account.any_instance.unstub(:redaction)
    super
  end

  def test_ticket_description_redaction
    user = add_new_user(Account.current, active: true)
    ticket = create_ticket({ requester_id: user.id, description_html: @description_html }, nil, nil, true)
    assert ticket.description.include?(@redacted_description)
    assert ticket.description_html.include?(@redacted_description)
  end

  def test_ticket_description_redaction_with_new_email
    ticket = create_ticket({ email: 'samsung@gmail.com', description_html: @description_html }, nil, nil, true, true)
    assert ticket.description.include?(@redacted_description)
    assert ticket.description_html.include?(@redacted_description)
  end

  def test_ticket_description_redaction_with_callback
    ticket = create_ticket({ email: 'samsung@gmail.com', description_html: 'Hi' }, nil, nil, true)
    ticket.ticket_body.redaction_processed = false
    ticket.ticket_body.description_html = @description_html
    ticket.ticket_body.save!
    ticket.reload
    assert ticket.description_html.include?(@redacted_description)
  end

  def test_ticket_description_redaction_with_agent_as_requester
    agent = add_agent(Account.current)
    ticket = create_ticket({ requester_id: agent.id, description_html: @description_html }, nil, nil, true)
    refute ticket.description.include?(@redacted_description)
    refute ticket.description_html.include?(@redacted_description)
  end

  def test_ticket_description_with_credit_card_redaction_off
    AccountAdditionalSettings.any_instance.stubs(:redaction).returns(credit_card_number: false)
    ticket = create_ticket({ email: 'samsung@gmail.com', description_html: @description_html }, nil, nil, true)
    refute ticket.description.include?(@redacted_description)
    refute ticket.description_html.include?(@redacted_description)
  end

  def test_ticket_description_redaction_without_feature
    Account.any_instance.stubs(:redaction_enabled?).returns(false)
    ticket = create_ticket({ email: 'samsung@gmail.com', description_html: @description_html }, nil, nil, true)
    refute ticket.description.include?(@redacted_description)
    refute ticket.description_html.include?(@redacted_description)
  end
end
