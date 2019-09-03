require_relative '../../test_helper'
require "#{Rails.root}/spec/support/agent_helper.rb"
class CustomizeDomainMailerTest < ActionView::TestCase
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

  def test_domain_changed
    recipient = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1).user
    I18n.locale = recipient.language
    mail_message = CustomizeDomainMailer.send_email(:domain_changed, recipient.email, to_email: recipient.email, name: recipient.first_name, url: @account.full_url, is_agent: !recipient.privilege?(:admin_tasks), account_name: @account.name)
    assert_equal recipient.email, mail_message.to.first
    assert_equal "#{@account.name}: Here's your new helpdesk URL", mail_message.subject
    html_part = mail_message.html_part ? mail_message.html_part.body.decoded : nil
    if html_part.present?
      test_part = 'The administrator has changed the URL of your helpdesk'
      assert_equal html_part.include?(test_part), true
    end
  ensure
    I18n.locale = 'de'
  end
end
