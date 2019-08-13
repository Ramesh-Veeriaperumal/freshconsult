require_relative '../../test_helper.rb'
require_relative '../../api/helpers/test_class_methods.rb'
require_relative '../../core/helpers/account_test_helper.rb'
require Rails.root.join('spec', 'support', 'user_helper.rb')

class WatcherNotifierTest < ActionMailer::TestCase
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

  def test_translation_for_token_expiry
    en_subject = I18n.t('mailer_notifier_subject.token_expiry')
    en_body    = I18n.t('mailer_notifier.ecommerce_notifier.token_expiry.token_expiry_msg')
    subject_bk = I18n.t('mailer_notifier_subject.token_expiry', locale: :fr)
    body_bk = I18n.t('mailer_notifier.ecommerce_notifier.token_expiry.token_expiry_msg', locale: :fr)
    I18n.backend.store_translations('fr', mailer_notifier_subject: { token_expiry: "$0$#{en_subject}" })
    I18n.backend.store_translations('fr', mailer_notifier: { ecommerce_notifier: { token_expiry: { token_expiry_msg: "$0$#{en_body}" } } })
    I18n.locale = 'en'
    user = add_test_agent(@account)
    user.language = 'fr'
    email = EcommerceNotifier.send_email(:token_expiry, user, 'TESTING-ECOM-NAME', @account, Date.new)
    body = email.body.encoded
    assert_equal true, email.subject.include?('$0$')
    assert_equal true, email.subject.include?('TESTING-ECOM-NAME')
    assert_equal true, body.include?('$0$')
    assert_equal true, body.include?('TESTING-ECOM-NAME')
    assert_equal true, I18n.locale.to_s.eql?('en')
    I18n.backend.store_translations('fr', mailer_notifier_subject: { token_expiry: subject_bk })
    I18n.backend.store_translations('fr', mailer_notifier: { ecommerce_notifier: { token_expiry: { token_expiry_msg: body_bk } } })
  ensure
    user.destroy if user
  end

  def test_notify_on_status_change_delayed
    user = add_test_agent(@account)
    user.language = 'fr'
    EcommerceNotifier.send_later(:token_expiry, 'TESTING-ECOM-NAME', @account, Date.new, locale_object: user)
    assert Delayed::Job.last.handler.include?('method: :token_expiry')
    assert Delayed::Job.last.handler.include?('TESTING-ECOM-NAME')
    assert Delayed::Job.last.handler.include?('locale_object:')
    assert Delayed::Job.last.handler.include?('language: fr')
  ensure
    user.destroy if user
  end
end
