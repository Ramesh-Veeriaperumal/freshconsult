require_relative '../../test_helper'
require "#{Rails.root}/spec/support/agent_helper.rb"
class CustomMailboxTest < ActionView::TestCase
  include AgentHelper
  def setup
    super
    @account = create_test_account if @account.nil?
    @account.make_current
    @account.tags.delete_all
    @account.tag_uses.delete_all
    Account.stubs(:multi_language_enabled?).returns(true)
    I18n.locale = 'de'
    Account.current.stubs(:language).returns('de')
  end

  def teardown
    I18n.locale = I18n.default_locale
    Account.current.unstub(:language)
    Account.unstub(:multi_language_enabled?)
  end

  def test_error
    recipient1 = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1).user
    recipient2 = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1).user
    recipient1.update_attributes(language: 'de')
    emails = [recipient1.email, recipient2.email]
    mail_message = CustomMailbox.send_email_to_group(:error, emails, email_mailbox: 'test')
    assert_equal mail_message['de'].first, recipient1.email
    assert_equal mail_message['en'].first, recipient2.email
  ensure
    recipient1.destroy
    recipient2.destroy
  end
end
