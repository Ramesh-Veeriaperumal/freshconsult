require_relative '../unit_test_helper'
require "#{Rails.root}/spec/support/agent_helper.rb"

class SecurityEmailNotificationTest < ActionView::TestCase
  include AgentHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_agent_email_change_delayed
    self_agent = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1).user
    doer_agent = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1).user
    delayed_job = SecurityEmailNotification.send_later(:deliver_agent_email_change_alert, self_agent, self_agent.email,
        ["primary email "], doer_agent, "agent_email_change", { :locale_object => self_agent })

    assert delayed_job.handler.include?('method: :deliver_agent_email_change_alert')
    assert delayed_job.handler.include?('agent_email_change')
  end

  def test_agent_email_change
    self_agent = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1).user
    doer_agent = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1).user
    mail_message = SecurityEmailNotification.agent_email_change_alert(self_agent, self_agent.email,
        ["primary email "], doer_agent, "agent_email_change")
    
    assert_equal self_agent.email, mail_message.to.first
    assert_equal "#{self_agent.account.helpdesk_name}: Agent email address changed", mail_message.subject
  end

  def test_admin_alert_email_change_delayed
    self_agent = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1).user
    doer_agent = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1).user
    delayed_job = SecurityEmailNotification.send_later(:deliver_agent_email_change_alert, self_agent, doer_agent.email,
        ["primary email "], doer_agent, "admin_alert_email_change", { :locale_object => doer_agent })

    assert delayed_job.handler.include?('method: :deliver_agent_email_change_alert')
    assert delayed_job.handler.include?('admin_alert_email_change')
  end

  def test_admin_alert_email_change
    self_agent = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1).user
    doer_agent = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1).user
    mail_message = SecurityEmailNotification.agent_email_change_alert(self_agent, doer_agent.email,
        ["primary email "], doer_agent, "admin_alert_email_change")
    
    assert_equal doer_agent.email, mail_message.to.first
    assert_equal "#{self_agent.account.helpdesk_name}: Agent email address changed", mail_message.subject
  end

  def test_agent_update_alert_delayed
    self_agent = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1).user
    delayed_job = SecurityEmailNotification.send_later(:deliver_agent_update_alert, self_agent,
        ["Phone number"], { :locale_object => self_agent })
    assert delayed_job.handler.include?('method: :deliver_agent_update_alert')
    assert delayed_job.handler.include?('Phone number')
  end

  def test_agent_update_alert
    self_agent = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1).user
    changed_attributes = ["Phone number"]

    mail_message = SecurityEmailNotification.agent_update_alert(self_agent, changed_attributes)

    assert_equal self_agent.email, mail_message.to.first
    assert_equal "Your #{changed_attributes.to_sentence} in #{self_agent.account.name} has been updated", mail_message.subject
  end

  def test_admin_alert_mail_delayed
    self_agent = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1).user
    subject = { key: 'mailer_notifier_subject.agent_added',
                locals: {
                  account_name: @account.name
                }
              }
    roles_name = self_agent.roles.map(&:name)
    delayed_job = SecurityEmailNotification.send_later(:deliver_admin_alert_mail, self_agent, subject,
        'agent_create', roles_name.to_a, self_agent.name)
    assert delayed_job.handler.include?('method: :deliver_admin_alert_mail')
    assert delayed_job.handler.include?('agent_create')
  end

  def test_admin_alert_mail
    recipient1 = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1, language: 'de').user
    recipient2 = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1, language: 'en').user
    emails = [recipient1.email, recipient2.email]
    subject = { key: 'mailer_notifier_subject.agent_added',
                locals: {
                  account_name: @account.name
                }
              }
    roles_name = recipient1.roles.map(&:name)
    mail_message = SecurityEmailNotification.send_email_to_group(:admin_alert_mail_message, emails, recipient1, subject, 'agent_create', roles_name.to_a, recipient2.name)
    assert_equal mail_message['de'].first, recipient1.email
    assert_equal mail_message['en'].first, recipient2.email
  end

  def test_admin_alert_mail_message
    self_agent = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1).user
    doer_agent = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1).user
    subject = { key: 'mailer_notifier_subject.agent_added',
                locals: {
                  account_name: @account.name
                }
              }
    roles_name = self_agent.roles.map(&:name)
    email_hash = { group: [self_agent.email], other: [doer_agent.email] }
    mail_message = SecurityEmailNotification.admin_alert_mail_message(email_hash, self_agent, subject, 'agent_create', roles_name.to_a, doer_agent.name)
    assert_equal "#{@account.name}: A new agent was added to your account", mail_message.subject
  end
end
