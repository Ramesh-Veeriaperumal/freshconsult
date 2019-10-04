require_relative '../../test_helper.rb'
require_relative '../../api/helpers/test_class_methods.rb'
require_relative '../../core/helpers/account_test_helper.rb'
require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'tickets_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'note_test_helper.rb')

class TodosReminderMailerTest < ActionMailer::TestCase
  include AccountTestHelper
  include CoreTicketsTestHelper
  include UsersHelper
  include NoteTestHelper

  def setup
    super
    create_test_account if @account.nil?
    Account.current.stubs(:language).returns('fr')
  end

  def teardown
    Account.current.unstub(:language)
    super
  end

  def test_translation_for_notify_new_watcher
    en_subject = I18n.t('mailer_notifier_subject.send_reminder_email')
    en_body    = I18n.t('todos_reminder.email.message')
    subject_bk = I18n.t('mailer_notifier_subject.send_reminder_email', locale: :fr)
    body_bk    = I18n.t('todos_reminder.email.message', locale: :fr)
    I18n.backend.store_translations('fr', mailer_notifier_subject: { send_reminder_email: "$0$#{en_subject}" })
    I18n.backend.store_translations('fr', todos_reminder: { email: { message: "$0$#{en_body}" } })
    I18n.locale = 'en'
    
    agent = add_test_agent(@account)
    ticket = create_ticket(responder_id: agent.id)
    agent.language = 'fr'
    email = TodosReminderMailer.send_email(:send_reminder_email, agent, agent,"TODO_BODY",ticket, "12/12/2021", 'www.test.com')
    assert_equal true, email.subject.include?('$0$')
    assert_equal true, email.subject.include?('TODO_BODY')
    assert_equal true, email.body.encoded.include?('$0$')
    assert_equal true, email.body.encoded.include?('12/12/2021')
    assert_equal true, I18n.locale.to_s.eql?('en')
    
    I18n.backend.store_translations('fr', mailer_notifier_subject: { send_reminder_email: subject_bk })
    I18n.backend.store_translations('fr', todos_reminder: { email: { message: body_bk } })
  ensure
    ticket.destroy if ticket
    agent.destroy if agent
  end
end
