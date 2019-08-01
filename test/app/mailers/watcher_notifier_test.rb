require_relative '../../test_helper.rb'
require_relative '../../api/helpers/test_class_methods.rb'
require_relative '../../core/helpers/account_test_helper.rb'
require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'tickets_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'note_test_helper.rb')

class WatcherNotifierTest < ActionMailer::TestCase
  include AccountTestHelper
  include CoreTicketsTestHelper
  include UsersHelper
  include NoteTestHelper

  def setup
    super
    create_test_account if @account.nil?
    Account.any_instance.stubs(:multi_language_enabled?).returns(true)
    Account.any_instance.stubs(:language).returns('fr')
    @agent = add_test_agent(@account, role: 4, active: 1, email: 'testxyz@yopmail.com')
    @ticket = create_ticket(email: 'sample@freshdesk.com', responder_id: @agent.id)
    @subscription = @ticket.subscriptions.build(user_id: @agent.id)
    @subscription.user.language = 'fr'
  end

  def teardown
    Account.any_instance.unstub(:language)
    Account.any_instance.unstub(:multi_language_enabled?)
    @ticket.destroy if @ticket
    @agent.destroy if @agent
    super
  end

  def test_translation_for_notify_new_watcher
    en_subject = I18n.t('mailer_notifier_subject.notify_new_watcher')
    en_body    = I18n.t('helpdesk.tickets.add_watcher.mail.hi')
    subject_bk = I18n.t('mailer_notifier_subject.notify_new_watcher', locale: :fr)
    body_bk    = I18n.t('helpdesk.tickets.add_watcher.mail.hi', locale: :fr)
    I18n.backend.store_translations('fr', mailer_notifier_subject: { notify_new_watcher: "$0$#{en_subject}" })
    I18n.backend.store_translations('fr', helpdesk: { tickets: { add_watcher: { mail: { hi: "$0$#{en_body}" } } } })
    I18n.locale = 'en'
    email = Helpdesk::WatcherNotifier.send_email(:notify_new_watcher, @subscription.user, @ticket, @subscription, 'Test_name')
    assert_equal true, email.subject.include?('$0$')
    assert_equal true, email.subject.include?(@ticket.subject)
    assert_equal true, email.body.encoded.include?('$0$')
    assert_equal true, I18n.locale.to_s.eql?('en')
    I18n.backend.store_translations('fr', mailer_notifier_subject: { notify_new_watcher: subject_bk })
    I18n.backend.store_translations('fr', helpdesk: { tickets: { add_watcher: { mail: { hi: body_bk } } } })
  end

  def test_translation_for_notify_on_reply
    en_subject = I18n.t('mailer_notifier_subject.notify_on_reply.')
    en_body    = I18n.t('helpdesk.tickets.add_watcher.mail.hi')
    subject_bk = I18n.t('mailer_notifier_subject.notify_on_reply', locale: :fr)
    body_bk    = I18n.t('helpdesk.tickets.add_watcher.mail.hi', locale: :fr)
    I18n.backend.store_translations('fr', mailer_notifier_subject: { notify_on_reply: "$0$#{en_subject}" })
    I18n.backend.store_translations('fr', helpdesk: { tickets: { add_watcher: { mail: { hi: "$0$#{en_body}" } } } })
    I18n.locale = 'en'
    note = create_note(ticket_id: @ticket.id)
    email = Helpdesk::WatcherNotifier.send_email(:notify_on_reply, @subscription.user, @ticket, @subscription, note)
    assert_equal true, email.subject.include?('$0$')
    assert_equal true, email.subject.include?(@ticket.subject)
    assert_equal true, email.body.encoded.include?('$0$')
    assert_equal true, I18n.locale.to_s.eql?('en')
    I18n.backend.store_translations('fr', mailer_notifier_subject: { notify_on_reply: subject_bk })
    I18n.backend.store_translations('fr', helpdesk: { tickets: { add_watcher: { mail: { hi: body_bk } } } })
  end

  def test_translation_for_notify_on_status_change
    en_subject = I18n.t('mailer_notifier_subject.notify_on_reply')
    en_body    = I18n.t('helpdesk.tickets.add_watcher.mail.hi')
    subject_bk = I18n.t('mailer_notifier_subject.notify_on_reply', locale: :fr)
    body_bk    = I18n.t('helpdesk.tickets.add_watcher.mail.hi', locale: :fr)
    I18n.backend.store_translations('fr', mailer_notifier_subject: { notify_on_reply: "$0$#{en_subject}" })
    I18n.backend.store_translations('fr', helpdesk: { tickets: { add_watcher: { mail: { hi: "$0$#{en_body}" } } } })
    I18n.locale = 'en'
    email = Helpdesk::WatcherNotifier.send_email(:notify_on_status_change, @subscription.user, @ticket, @subscription, 'OPEN', 'Test_name')
    assert_equal true, email.subject.include?('$0$')
    assert_equal true, email.subject.include?(@ticket.subject)
    assert_equal true, email.body.encoded.include?('$0$')
    assert_equal true, I18n.locale.to_s.eql?('en')
    I18n.backend.store_translations('fr', mailer_notifier_subject: { notify_on_reply: subject_bk })
    I18n.backend.store_translations('fr', helpdesk: { tickets: { add_watcher: { mail: { hi: body_bk } } } })
  end

  def test_notify_on_status_change_delayed
    Helpdesk::WatcherNotifier.send_later(:notify_on_status_change, @ticket, @subscription, 'OPEN', 'Test_name', locale_object: @subscription.user)
    assert Delayed::Job.last.handler.include?('method: :notify_on_status_change')
    assert Delayed::Job.last.handler.include?('Test_name')
    assert Delayed::Job.last.handler.include?('locale_object:')
    assert Delayed::Job.last.handler.include?('language: fr')
  end
end
