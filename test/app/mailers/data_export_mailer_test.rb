require_relative '../../test_helper'
require_relative '../../api/helpers/test_class_methods.rb'
['scheduled_export_helper.rb', 'ticket_helper.rb'].each { |file| require Rails.root.join('spec', 'support', file) }

class DataExportMailerTest < ActionMailer::TestCase
  include ScheduledExportHelper
  include TicketHelper
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

  def test_export_failure
    recipient = add_agent(@account)
    options = {
      user: recipient,
      type: 'customer',
      domain: @account.domain
    }
    mail_message = DataExportMailer.send_email(:export_failure, recipient, options)
    assert_equal recipient.email, mail_message.to.first
    assert_equal "#{options[:type].capitalize} export for #{options[:domain]}", mail_message.subject
    email_body = mail_message.body.present? ? mail_message.body.decoded : nil
    if email_body.present?
      test_part = 'An error occurred while exporting data.'
      assert_equal email_body.include?(test_part), true
    end
  end

  def test_customer_export
    recipient = add_agent(@account)
    options = {
      user: recipient,
      type: 'customer',
      domain: @account.domain,
      url: 'example.com'
    }
    mail_message = DataExportMailer.send_email(:customer_export, recipient, options)
    assert_equal recipient.email, mail_message.to.first
    assert_equal "#{options[:type].capitalize} export for #{options[:domain]}", mail_message.subject
    email_body = mail_message.body.present? ? mail_message.body.decoded : nil
    if email_body.present?
      test_part = "The #{options[:type]} export you had requested is complete."
      assert_equal email_body.include?(test_part), true
    end
  end

  def test_scheduled_ticket_export_message
    recipient1 = add_agent(@account)
    recipient2 = add_agent(@account)
    options = { id: 1232, name: 'schedule export test2', schedule_type: 1, user_id: recipient1.id,
                filter_data: [{ name: :status, operator: :is, value: ['2'] }],
                fields_data: { ticket: { display_id: 'Ticket Id', subject: 'Subject', status_name: 'Status' },
                               contact: { email: 'Email', phone: 'Work phone' } },
                schedule_details: { frequency: '1', minute_of_day: '13', delivery_type: 1,
                                    email_recipients: [recipient1.id, recipient2.id], initial_export: '1' } }
    scheduled_export = add_scheduled_export(@account, options)
    schedule = @account.scheduled_ticket_exports.find_by_id(scheduled_export.id)
    email_hash = { group: [recipient1.email], other: [recipient2.email] }
    I18n.locale = 'en'
    mail_message = DataExportMailer.scheduled_ticket_export_message(email_hash, @account, schedule)
    assert_equal mail_message.to.first, recipient1.email
    email_body = mail_message.body.present? ? mail_message.body.decoded : nil
    if email_body.present?
      test_part = 'This report has the details of tickets that were created and updated'
      assert_equal email_body.include?(test_part), true
    end
  ensure
    I18n.locale = 'de'
    scheduled_export.destroy
    recipient1.destroy
    recipient2.destroy
  end

  def test_scheduled_ticket_export_no_data_message
    recipient1 = add_agent(@account)
    recipient2 = add_agent(@account)
    options = { id: 1234, name: 'schedule export test4', schedule_type: 1, user_id: recipient1.id,
                filter_data: [{ name: :status, operator: :is, value: ['2'] }],
                fields_data: { ticket: { display_id: 'Ticket Id', subject: 'Subject', status_name: 'Status' },
                               contact: { email: 'Email', phone: 'Work phone' } },
                schedule_details: { frequency: '1', minute_of_day: '13', delivery_type: 1,
                                    email_recipients: [recipient1.id, recipient2.id], initial_export: '1' } }
    scheduled_export = add_scheduled_export(@account, options)
    schedule = @account.scheduled_ticket_exports.find_by_id(scheduled_export.id)
    email_hash = { group: [recipient1.email], other: [recipient2.email] }
    I18n.locale = 'en'
    mail_message = DataExportMailer.scheduled_ticket_export_no_data_message(email_hash, @account, schedule)
    assert_equal mail_message.to.first, recipient1.email
    email_body = mail_message.body.present? ? mail_message.body.decoded : nil
    if email_body.present?
      test_part = 'You have no tickets created or updated'
      assert_equal email_body.include?(test_part), true
    end
  ensure
    I18n.locale = 'de'
    scheduled_export.destroy
    recipient1.destroy
    recipient2.destroy
  end

  def test_ticket_export_case1
    recipient = add_agent(@account)
    export_params = { archived_tickets: true, use_es: true, export_name: 'TestTicket' }
    options = {
      user: recipient,
      type: 'ticket',
      url: 'example.com',
      domain: @account.domain,
      export_params: export_params
    }
    I18n.locale = 'en'
    mail_message = DataExportMailer.send_email(:ticket_export, recipient, options)
    assert_equal recipient.email, mail_message.to.first
    assert_equal mail_message.subject.include?(export_params[:export_name]), true
    email_body = mail_message.body.present? ? mail_message.body.decoded : nil
    if email_body.present?
      test_body_part = 'The ticket export you had requested is complete.'
      assert_equal email_body.include?(test_body_part), true
    end
  ensure
    I18n.locale = 'de'
    recipient.destroy
  end

  def test_ticket_export_case2
    recipient = add_agent(@account)
    export_params = { archived_tickets: true, use_es: false, ticket_state_filter: 'out_of_sla',
                      start_date: '01-01-2019', end_date: '07-01-2019', domain: 'example.com' }
    options = {
      user: recipient,
      type: 'ticket',
      url: 'example.com',
      domain: @account.domain,
      export_params: export_params
    }
    I18n.locale = 'en'
    mail_message = DataExportMailer.send_email(:ticket_export, recipient, options)
    assert_equal recipient.email, mail_message.to.first
    test_subject_part = 'Export of tickets'
    assert_equal mail_message.subject.include?(test_subject_part), true
    email_body = mail_message.body.present? ? mail_message.body.decoded : nil
    if email_body.present?
      test_body_part = 'The ticket export you had requested is complete.'
      assert_equal email_body.include?(test_body_part), true
    end
  ensure
    I18n.locale = 'de'
    recipient.destroy
  end

  def test_data_backup_failure
    recipient = add_agent(@account)
    options = {
      email: recipient.email,
      domain: 'example.com',
      host: @account.host
    }
    I18n.locale = 'en'
    mail_message = DataExportFailureMailer.send_email(:data_backup_failure, options[:email], options)
    assert_equal mail_message.to.first, recipient.email
    assert_equal mail_message.subject, I18n.t('mailer_notifier_subject.data_export', host: options[:host])
    email_body = mail_message.body.present? ? mail_message.body.decoded : nil
    if email_body.present?
      test_part = 'Your data export has failed'
      assert_equal email_body.include?(test_part), true
    end
  ensure
    I18n.locale = 'de'
    recipient.destroy
  end

  def test_broadcast_message
    ticket = create_ticket
    sender = add_agent(@account)
    recipient1 = add_agent(@account)
    recipient2 = add_agent(@account)
    options = {
      from_email: sender.email,
      url: 'example.com',
      ticket_subject: ticket.subject,
      content: 'test content',
      ticket_id: ticket.display_id,
      account_id: ticket.account_id
    }
    email_hash = { group: [recipient1.email], other: [recipient2.email] }
    I18n.locale = 'en'
    mail_message = DataExportMailer.deliver_broadcast_message(email_hash, options)
    assert_equal mail_message.to.first, recipient1.email
    assert mail_message.subject.include?('Broadcast Message Added')
    email_body = mail_message.body.present? ? mail_message.body.decoded : nil
    if email_body.present?
      test_part = 'Message Content:'
      assert_equal email_body.include?(test_part), true
    end
  ensure
    I18n.locale = 'de'
    recipient1.destroy
    recipient2.destroy
    sender.destroy
    ticket.destroy
  end

  def test_article_export_mail
    recipient = add_agent(@account)
    export_params = { export_name: 'Article Export' }
    options = {
      user: recipient,
      type: 'article',
      url: 'example.com',
      domain: @account.domain,
      export_params: export_params
    }
    I18n.locale = 'en'

    mail_message = DataExportMailer.send_email(:article_export, recipient, options)

    assert_equal recipient.email, mail_message.to.first
    assert_equal mail_message.subject.include?(export_params[:export_name]), true
    email_body = mail_message.body.decoded
    test_body_part = 'The article export you had requested is complete.'
    assert_equal email_body.include?(test_body_part), true
  ensure
    I18n.locale = 'de'
    recipient.destroy
  end

  def test_article_export_failed_mail
    recipient = add_agent(@account)
    export_params = { export_name: 'Article Export' }
    options = {
      user: recipient,
      type: 'article',
      url: 'example.com',
      domain: @account.domain,
      export_params: export_params
    }
    I18n.locale = 'en'

    mail_message = DataExportMailer.send_email(:export_failure, recipient, options)

    assert_equal recipient.email, mail_message.to.first
    assert_equal mail_message.subject.include?(export_params[:export_name]), true
    email_body = mail_message.body.decoded
    test_body_part = 'An error occurred while exporting data. Please try again or contact Freshdesk support.'
    assert_equal email_body.include?(test_body_part), true
  ensure
    I18n.locale = 'de'
    recipient.destroy
  end
end
