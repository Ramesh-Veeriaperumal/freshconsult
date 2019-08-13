require_relative '../../test_helper.rb'
require_relative '../../api/helpers/test_class_methods.rb'
require_relative '../../core/helpers/account_test_helper.rb'
require Rails.root.join('spec', 'support', 'user_helper.rb')

class DraftMailerTest < ActionMailer::TestCase
  include AccountTestHelper
  include UsersHelper

  def setup
    super
    create_test_account if @account.nil?
    Account.stubs(:multi_language_enabled?).returns(true)
    Account.current.stubs(:language).returns('fr')
  end

  def teardown
    Account.current.unstub(:language)
    Account.unstub(:multi_language_enabled?)
    super
  end

  def test_translation_for_discard_email
    en_subject = I18n.t('mailer_notifier_subject.discard_email')
    en_body    = I18n.t('mailer_notifier.draft_mailer.discard_email.discard_msg_html')
    subject_bk = I18n.t('mailer_notifier_subject.discard_email', locale: :fr)
    body_bk    = I18n.t('mailer_notifier.draft_mailer.discard_email.discard_msg_html', locale: :fr)
    I18n.backend.store_translations('fr', mailer_notifier_subject: { discard_email: "$0$#{en_subject}" })
    I18n.backend.store_translations('fr', mailer_notifier: { draft_mailer: { discard_email: { discard_msg_html: "$0$#{en_body}" } } })
    I18n.locale = 'en'
    user1 = add_test_agent(@account)
    user2 = add_test_agent(@account)
    user1.language = 'fr'
    draft_mock = { id: 1, title: 'TEST-DRAFT-TITLE', article_id: 1, description: '<div>test-description</div>' }
    article_mock = { id: 1, article_id: 1 }
    portal = Account.current.main_portal
    email = DraftMailer.send_email(:discard_email, user1, draft_mock, article_mock, user1, user2, portal)
    body = email.body.encoded
    assert_equal true, email.subject.include?('$0$')
    assert_equal true, email.subject.include?('TEST-DRAFT-TITLE')
    assert_equal true, body.include?('$0$')
    assert_equal true, body.include?(user1.name)
    assert_equal true, I18n.locale.to_s.eql?('en')
    I18n.backend.store_translations('fr', mailer_notifier_subject: { discard_email: subject_bk })
    I18n.backend.store_translations('fr', mailer_notifier: { draft_mailer: { discard_email: { discard_msg_html: body_bk } } })
  ensure
    user1.destroy if user1
    user2.destroy if user2
  end
end
