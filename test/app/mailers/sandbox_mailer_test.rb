require_relative '../../test_helper'
require_relative '../../api/helpers/test_class_methods.rb'

class SandboxMailerTest < ActionMailer::TestCase
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

  def test_sandbox_merge_notifier
    recipient1 = add_agent(@account)
    recipient2 = add_agent(@account)
    I18n.locale = recipient1.language
    data = {
        notifier: 'merge_notifier',
        subject: 'Sandbox sync complete!',
        recipients: [recipient1.email, recipient2.email],
        additional_info: {
            sandbox_url: Account.current.sandbox_domain,
            account_name: @account.name,
            email_data: {success_diff: {}, failure_diff: {}}
        }
    }
    email_hash = {group: data[:recipients], other: []}
    mail_message = Admin::SandboxMailer.sandbox_mailer(email_hash, @account, data)
    assert_equal mail_message.to.first, recipient1.email
    assert_equal mail_message.subject, 'Sandbox sync complete!'
  ensure
    I18n.locale = 'de'
  end

  def test_sandbox_live_notifier
    recipient1 = add_agent(@account)
    recipient2 = add_agent(@account)
    I18n.locale = recipient1.language
    data = {
        notifier: 'notifier',
        subject: 'Sandbox is live',
        recipients: [recipient1.email, recipient2.email],
        additional_info: {
            sandbox_url: Account.current.sandbox_domain,
            account_name: @account.name
        }
    }
    email_hash = {group: data[:recipients], other: []}
    mail_message = Admin::SandboxMailer.sandbox_mailer(email_hash, @account, data)
    assert_equal mail_message.to.first, recipient1.email
    assert_equal mail_message.subject, 'Sandbox is live'
  ensure
    I18n.locale = 'de'
  end
end