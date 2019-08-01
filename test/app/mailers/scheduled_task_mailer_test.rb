require_relative '../../test_helper'
['scheduled_task_helper.rb'].each { |file| require Rails.root.join('spec', 'support', file) }

class ScheduledTaskMailerTest < ActionView::TestCase
  include ScheduledTaskHelper
  def setup
    super
    @account = create_test_account if @account.nil?
    @account.make_current
    @account.tags.delete_all
    @account.tag_uses.delete_all
    Account.stubs(:multi_language_enabled?).returns(true)
    I18n.locale = 'de'
  end

  def teardown
    I18n.locale = I18n.default_locale
    Account.unstub(:multi_language_enabled?)
  end

  def test_notify_blocked_or_deleted
    recipient1 = add_agent(@account)
    recipient2 = add_agent(@account)
    options = { scheduled_type: 'Helpdesk::ReportFilter', filter_name: 'Agent Performance', report_type: 1004, frequency: 1, agents: { agent1: recipient1, agent2: recipient2 } }
    task = add_scheduled_task(@account, options)
    mail_message = ScheduledTaskMailer.send_email(:notify_blocked_or_deleted, task.user, task, blocked_emails: [recipient2])
    assert_equal mail_message.to.first, recipient1.email
    assert_equal mail_message.subject, '[Important] Scheduled report - Recipient update required'
    html_part = mail_message.html_part ? mail_message.html_part.body.decoded : nil
    if html_part.present?
      test_part = 'The scheduled report that you created for'
      assert_equal html_part.include?(test_part), true
    end
    assert_equal :de, I18n.locale
  ensure
    task.schedulable.destroy
    task.destroy
    recipient1.destroy
    recipient2.destroy
  end

  def test_notify_downgraded_user
    recipient1 = add_agent(@account)
    recipient2 = add_agent(@account)
    options = { scheduled_type: 'Helpdesk::ReportFilter', filter_name: 'Agent Performance', report_type: 1004, frequency: 1, agents: { agent1: recipient1, agent2: recipient2 } }
    task = add_scheduled_task(@account, options)
    mail_message = ScheduledTaskMailer.send_email(:notify_downgraded_user, task.user, task, agent_downgraded: [recipient2])
    assert_equal mail_message.to.first, recipient1.email
    assert_equal mail_message.subject, '[Important] Scheduled report - Recipient update required'
    html_part = mail_message.html_part ? mail_message.html_part.body.decoded : nil
    if html_part.present?
      test_part = 'The scheduled report that you created for'
      assert_equal html_part.include?(test_part), true
    end
    assert_equal :de, I18n.locale
  ensure
    task.schedulable.destroy
    task.destroy
    recipient1.destroy
    recipient2.destroy
  end

  def test_report_no_data_email_message
    recipient1 = add_agent(@account)
    recipient2 = add_agent(@account)
    I18n.locale = recipient1.language
    options = { scheduled_type: 'Helpdesk::ReportFilter', filter_name: 'Agent Performance', report_type: 1004, frequency: 1, agents: { agent1: recipient1, agent2: recipient2 } }
    task = add_scheduled_task(@account, options)
    config = task.schedule_configurations.first
    portal_name = 'Test Case'
    emails = { group: [recipient1.email, recipient2.email], other: ['random1@xyz.com', 'random2@xyz.com'] }
    mail_message = ScheduledTaskMailer.report_no_data_email_message(emails, task: task, portal_name: portal_name, config: config)
    assert_equal mail_message.to.first, recipient1.email
    html_part = mail_message.html_part ? mail_message.html_part.body.decoded : nil
    if html_part.present?
      test_part = 'Seems like there is no data to display'
      assert_equal html_part.include?(test_part), true
    end
  ensure
    I18n.locale = 'de'
    task.schedulable.destroy
    task.destroy
    recipient1.destroy
    recipient2.destroy
  end
end
