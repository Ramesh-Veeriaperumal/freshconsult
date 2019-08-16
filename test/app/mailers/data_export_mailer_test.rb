require_relative '../../test_helper'
require_relative '../../api/helpers/test_class_methods.rb'

class DataExportMailerTest < ActionMailer::TestCase
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

  def test_data_backup
    recipient = add_agent(@account)
    email_params = {
        email: recipient.email,
        domain: @account.domain,
        host: @account.host,
        url: 'example.com'
        }
    mail_message = DataExportMailer.send_email(:data_backup, recipient.email, email_params)
    assert_equal recipient.email, mail_message.to.first
    assert_equal "Data Export for #{@account.host}", mail_message.subject
    email_body = mail_message.body.present? ? mail_message.body.decoded : nil
    if email_body.present?
      test_part = 'Your data export is ready for download.'
      assert_equal email_body.include?(test_part), true
    end
  end

  def test_no_tickets
    recipient = add_agent(@account)
    email_params = { user: recipient, domain: @account.domain }
    mail_message = DataExportMailer.send_email(:no_tickets, recipient, email_params)
    assert_equal recipient.email, mail_message.to.first
    assert_equal "No tickets in range - #{@account.domain}", mail_message.subject
    email_body = mail_message.body.present? ? mail_message.body.decoded : nil
    if email_body.present?
      test_part = 'Seems like there are no tickets in the provided date range.'
      assert_equal email_body.include?(test_part), true
    end
  end

  def test_audit_log_export
    recipient = add_agent(@account)
    email_params = {
        user: recipient,
        domain: @account.domain,
        url: 'example.com',
        email: recipient.email,
        type: 'audit_log'
    }
    mail_message = DataExportMailer.send_email(:audit_log_export, recipient, email_params)
    assert_equal recipient.email, mail_message.to.first
    assert_equal "Audit Log Export for #{@account.domain}", mail_message.subject
    email_body = mail_message.body.present? ? mail_message.body.decoded : nil
    if email_body.present?
      test_part = 'You can download the file from'
      assert_equal email_body.include?(test_part), true
    end
  end

  def test_audit_log_export_failure
    recipient = add_agent(@account)
    email_params = {
        user: recipient,
        domain: @account.domain,
        email: recipient.email,
        type: 'audit_log'
    }
    mail_message = DataExportMailer.send_email(:audit_log_export_failure, recipient, email_params)
    assert_equal recipient.email, mail_message.to.first
    assert_equal 'Audit Log Export', mail_message.subject
    email_body = mail_message.body.present? ? mail_message.body.decoded : nil
    if email_body.present?
      test_part = 'An error occurred while exporting data'
      assert_equal email_body.include?(test_part), true
    end
  end

  def test_no_logs
    recipient = add_agent(@account)
    email_params = {
        user: recipient,
        domain: @account.domain,
        email: recipient.email,
        type: 'audit_log'
    }
    mail_message = DataExportMailer.send_email(:no_logs, recipient, email_params)
    assert_equal recipient.email, mail_message.to.first
    assert_equal 'Audit Log Export', mail_message.subject
    email_body = mail_message.body.present? ? mail_message.body.decoded : nil
    if email_body.present?
      test_part = 'There is no logs for given request. Please try with different timeline or filter'
      assert_equal email_body.include?(test_part), true
    end
  end

  def test_agent_export
    recipient = add_agent(@account)
    email_params = {
        user: recipient,
        domain: @account.domain,
        url: 'example.com'
        }
    mail_message = DataExportMailer.send_email(:deliver_agent_export, recipient, email_params)
    assert_equal recipient.email, mail_message.to.first
    assert_equal 'Agents List Export', mail_message.subject
    email_body = mail_message.body.present? ? mail_message.body.decoded : nil
    if email_body.present?
      test_part = 'You can download the file from'
      assert_equal email_body.include?(test_part), true
    end
  end
end
