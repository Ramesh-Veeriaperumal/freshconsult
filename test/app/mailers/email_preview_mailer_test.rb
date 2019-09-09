require_relative '../../test_helper'
require_relative '../../api/helpers/test_class_methods.rb'

class EmailPreviewMailerTest < ActionMailer::TestCase
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

  def test_preview_email_delayed
    recipient = add_agent(@account)
    recipient.update_attributes(language: 'de')
    subject = 'Test subject'
    mail_body = 'Test content'
    delayed_job = EmailPreviewMailer.send_later(:send_test_email, mail_body, subject, recipient.email, locale_object: recipient)
    assert delayed_job.handler.include?('method: :send_test_email')
  ensure
    recipient.destroy if recipient
  end

  def test_preview_email
    recipient = add_agent(@account)
    subject = 'Test subject'
    mail_body = 'Test content'
    I18n.locale = 'en'
    mail_message = EmailPreviewMailer.send_test_email(mail_body, subject, recipient.email)
    assert_equal recipient.email, mail_message.to.first
    assert_equal mail_message.subject.include?('Test Mail'), true
  ensure
    recipient.destroy if recipient
  end
end
