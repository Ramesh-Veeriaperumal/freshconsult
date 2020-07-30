require_relative '../unit_test_helper'
require_relative '../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class Office365PayloadTest < ActionView::TestCase
  include AccountTestHelper
  include TicketHelper

  def setup
    super
    before_all
  end

  def teardown
    super
  end

  def before_all
    @account = Account.current || create_account_if_not_exists
    ticket = create_ticket
    payload = {
      act_on_object: ticket,
      act_hash: { name: 'Integrations::Office365ActionHandler', office365_text: 'Ticket details', value: 'office365_trigger' },
      triggered_event: { 'priority' => [1, 3] }
    }
    @service_class = ::IntegrationServices::Services::Office365Service.new(nil, payload)
  end

  def create_account_if_not_exists
    user = create_test_account
    user.account
  end

  def test_with_adaptive_card
    html_content = @service_class.safe_send(:generate_html_content)
    assert html_content.include?('<script type="application/ld+json">')
    assert html_content.include?('<script type="application/adaptivecard+json">')
  end

end
