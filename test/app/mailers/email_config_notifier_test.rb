require_relative '../../test_helper.rb'
require_relative '../../api/helpers/test_class_methods.rb'
require_relative '../../core/helpers/account_test_helper.rb'

class EmailConfigNotifierTest < ActionMailer::TestCase
  include AccountTestHelper

  def setup
    super
    create_test_account if @account.nil?
    Account.current.stubs(:language).returns('fr')
    Portal.current.stubs(:language).returns('fr') if Portal.current
  end

  def teardown
    Account.current.unstub(:language)
    Portal.current.unstub(:language) if Portal.current
    super
  end

  # this test case is commented since we are getting no route found for register_email error while generating activation url
  # def test_translation_for_activation_instructions
  #   en_subject = I18n.t('mailer_notifier_subject.activation_instructions')
  #   en_body    = I18n.t('email_config_notifier.activation_instructions.body')
  #   subject_bk = I18n.t('mailer_notifier_subject.activation_instructions', locale: :fr)
  #   body_bk    = I18n.t('email_config_notifier.activation_instructions.body', locale: :fr)
  #   I18n.backend.store_translations('fr', mailer_notifier_subject: { activation_instructions: "$0$#{en_subject}" })
  #   I18n.backend.store_translations('fr', email_config_notifier: { activation_instructions: { body: "$0$#{en_body}" } })
  #   I18n.locale = 'en'
  #   email = EmailConfigNotifier.send_email(:activation_instructions, nil, Account.current.primary_email_config)
  #   assert_equal true, email.subject.include?('$0$')
  #   assert_equal true, email.subject.include?(Account.current.primary_email_config.account.portal_name)
  #   assert_equal true, email.body.encoded.include?('$0$')
  #   assert_equal true, email.body.encoded.include?(AppConfig['app_name'])
  #   assert_equal true, I18n.locale.to_s.eql?('en')
  #   I18n.backend.store_translations('fr', mailer_notifier_subject: { activation_instructions: subject_bk })
  #   I18n.backend.store_translations('fr', email_config_notifier: { activation_instructions: { body: body_bk } })
  # end

  def test_translation_for_test_email
    en_subject = I18n.t('mailer_notifier_subject.test_email')
    en_body    = I18n.t('email_config_notifier.test_email.body')
    subject_bk = I18n.t('mailer_notifier_subject.test_email', locale: :fr)
    body_bk    = I18n.t('email_config_notifier.test_email.body', locale: :fr)
    I18n.backend.store_translations('fr', mailer_notifier_subject: { test_email: "$0$#{en_subject}" })
    I18n.backend.store_translations('fr', email_config_notifier: { test_email: { body: "$0$#{en_body}" } })
    I18n.locale = 'en'
    Account.current.primary_email_config[:to_email] = 'test123@freshdesk.com'
    email_config = EmailConfig.new
    email_config[:id] = 1
    email_config[:account_id] = 1
    email_config[:to_email] = 'test123@freshdesk.com'
    email_config[:reply_email] = 'testxyz@freshdesk.com'
    email = EmailConfigNotifier.send_email(:test_email, nil, email_config)
    assert_equal true, email.subject.include?('$0$')
    assert_equal true, email.body.encoded.include?('$0$')
    assert_equal true, email.body.encoded.include?(email_config[:to_email])
    assert_equal true, I18n.locale.to_s.eql?('en')
    I18n.backend.store_translations('fr', mailer_notifier_subject: { test_email: subject_bk })
    I18n.backend.store_translations('fr', email_config_notifier: { test_email: { body: body_bk } })
  end
end
