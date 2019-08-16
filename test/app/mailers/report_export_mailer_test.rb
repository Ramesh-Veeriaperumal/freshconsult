require_relative '../../test_helper.rb'
require_relative '../../api/helpers/test_class_methods.rb'
require_relative '../../core/helpers/account_test_helper.rb'
require Rails.root.join('spec', 'support', 'user_helper.rb')

class ReportExportMailerTest < ActionMailer::TestCase
  include AccountTestHelper
  include UsersHelper

  def setup
    super
    create_test_account if @account.nil?
    Account.current.stubs(:language).returns('fr')
  end

  def teardown
    Account.current.unstub(:language)
    super
  end

  def test_translation_bi_report_exportl
    en_subject = I18n.t('mailer_notifier_subject.ticket_export')
    en_body    = I18n.t('mailer_notifier.report_export_mailer.bi_report_export.report_download_html')
    subject_bk = I18n.t('mailer_notifier_subject.ticket_export', locale: :fr)
    body_bk    = I18n.t('mailer_notifier.report_export_mailer.bi_report_export.report_download_html', locale: :fr)
    I18n.backend.store_translations('fr', mailer_notifier_subject: { ticket_export: "$0$#{en_subject}" })
    I18n.backend.store_translations('fr', mailer_notifier: { report_export_mailer: { bi_report_export: { report_download_html: "$0$#{en_body}" } } })
    I18n.locale = 'en'
    user = add_test_agent(@account)
    user.language = 'fr'
    options = { user: user, filters: [{ 'name' => 'status', 'value' => 'open' }, { 'name' => 'priority', 'value' => 'high' }], date_range: '1/1/20018-31/12/2018', report_type: 'ticket', filter_name: 'Open-High', ticket_export: true, selected_metric: 'Critical', portal_name: 'Test Portal', export_url: 'www.test.com' }
    email = ReportExportMailer.send_email(:bi_report_export, user, options)
    assert_equal true, email.subject.include?('$0$')
    assert_equal true, email.subject.include?('1/1/20018-31/12/2018')
    assert_equal true, email.body.encoded.include?('$0$')
    assert_equal true, email.body.encoded.include?('1/1/20018-31/12/2018')
    assert_equal true, email.body.encoded.include?('Open-High')
    assert_equal true, I18n.locale.to_s.eql?('en')
    I18n.backend.store_translations('fr', mailer_notifier_subject: { ticket_export: subject_bk })
    I18n.backend.store_translations('fr', mailer_notifier: { report_export_mailer: { bi_report_export: { report_download_html: body_bk } } })
  ensure
    user.destroy if user
  end

  def test_translation_no_report_data
    en_subject = I18n.t('mailer_notifier_subject.ticket_export')
    en_body    = I18n.t('mailer_notifier.report_export_mailer.no_report_data.main_msg')
    subject_bk = I18n.t('mailer_notifier_subject.ticket_export', locale: :fr)
    body_bk    = I18n.t('mailer_notifier.report_export_mailer.no_report_data.main_msg', locale: :fr)
    I18n.backend.store_translations('fr', mailer_notifier_subject: { ticket_export: "$0$#{en_subject}" })
    I18n.backend.store_translations('fr', mailer_notifier: { report_export_mailer: { no_report_data: { main_msg: "$0$#{en_body}" } } })
    I18n.locale = 'en'
    user = add_test_agent(@account)
    user.language = 'fr'
    options = { user: user, filters: [{ 'name' => 'status', 'value' => 'open' }, { 'name' => 'priority', 'value' => 'high' }], date_range: '1/1/20018-31/12/2018', report_type: 'ticket', filter_name: 'Open-High', ticket_export: true, selected_metric: 'Critical', portal_name: 'Test Portal', export_url: 'www.test.com' }
    email = ReportExportMailer.send_email(:no_report_data, user, options)
    assert_equal true, email.subject.include?('$0$')
    assert_equal true, email.subject.include?('1/1/20018-31/12/2018')
    assert_equal true, email.body.encoded.include?('$0$')
    assert_equal true, email.body.encoded.include?('1/1/20018-31/12/2018')
    assert_equal true, I18n.locale.to_s.eql?('en')
    I18n.backend.store_translations('fr', mailer_notifier_subject: { ticket_export: subject_bk })
    I18n.backend.store_translations('fr', mailer_notifier: { report_export_mailer: { no_report_data: { main_msg: body_bk } } })
  ensure
    user.destroy if user
  end

  def test_translation_exceeds_file_size_limit
    en_subject = I18n.t('mailer_notifier_subject.ticket_export')
    en_body    = I18n.t('mailer_notifier.report_export_mailer.exceeds_file_size_limit.file_size_error')
    subject_bk = I18n.t('mailer_notifier_subject.ticket_export', locale: :fr)
    body_bk    = I18n.t('mailer_notifier.report_export_mailer.exceeds_file_size_limit.file_size_error', locale: :fr)
    I18n.backend.store_translations('fr', mailer_notifier_subject: { ticket_export: "$0$#{en_subject}" })
    I18n.backend.store_translations('fr', mailer_notifier: { report_export_mailer: { exceeds_file_size_limit: { file_size_error: "$0$#{en_body}" } } })
    I18n.locale = 'en'
    user = add_test_agent(@account)
    user.language = 'fr'
    options = { user: user, filters: [{ 'name' => 'status', 'value' => 'open' }, { 'name' => 'priority', 'value' => 'high' }], date_range: '1/1/20018-31/12/2018', report_type: 'ticket', filter_name: 'Open-High', ticket_export: true, selected_metric: 'Critical', portal_name: 'Test Portal', export_url: 'www.test.com' }
    email = ReportExportMailer.send_email(:exceeds_file_size_limit, user, options)
    assert_equal true, email.subject.include?('$0$')
    assert_equal true, email.subject.include?('1/1/20018-31/12/2018')
    assert_equal true, email.body.encoded.include?('$0$')
    assert_equal true, email.body.encoded.include?('1/1/20018-31/12/2018')
    assert_equal true, email.body.encoded.include?('Open-High')
    assert_equal true, I18n.locale.to_s.eql?('en')
    I18n.backend.store_translations('fr', mailer_notifier_subject: { ticket_export: subject_bk })
    I18n.backend.store_translations('fr', mailer_notifier: { report_export_mailer: { exceeds_file_size_limit: { file_size_error: body_bk } } })
  ensure
    user.destroy if user
  end

  def test_translation_report_export_task
    en_subject = I18n.t('mailer_notifier_subject.ticket_export')
    en_body    = I18n.t('mailer_notifier.report_export_mailer.report_export_task.cvs_report_request')
    subject_bk = I18n.t('mailer_notifier_subject.ticket_export', locale: :fr)
    body_bk    = I18n.t('mailer_notifier.report_export_mailer.report_export_task.cvs_report_request', locale: :fr)
    I18n.backend.store_translations('fr', mailer_notifier_subject: { ticket_export: "$0$#{en_subject}" })
    I18n.backend.store_translations('fr', mailer_notifier: { report_export_mailer: { report_export_task: { cvs_report_request: "$0$#{en_body}" } } })
    I18n.locale = 'en'
    user = add_test_agent(@account)
    user.language = 'fr'
    options = { task_email_ids: [user.email], filters: [{ 'name' => 'status', 'value' => 'open' }, { 'name' => 'priority', 'value' => 'high' }], date_range: '1/1/20018-31/12/2018', report_type: 'ticket', invalid_count: 10, ticket_export: true, description: 'Critical', portal_name: 'Test Portal', task_start_time: '10:30' }
    email = ReportExportMailer.send_email(:report_export_task, user, { group: [user.email], other: ['abc@abc.com', 'xyz@xyz.com'] }, options)
    assert_equal true, email.subject.include?('$0$')
    assert_equal true, email.subject.include?('1/1/20018-31/12/2018')
    assert_equal true, email.body.encoded.include?('$0$')
    assert_equal true, email.body.encoded.include?('1/1/20018-31/12/2018')
    assert_equal true, email.body.encoded.include?('No. of invalid accounts')
    assert_equal true, email.body.encoded.include?('abc@abc.com')
    assert_equal true, I18n.locale.to_s.eql?('en')
    I18n.backend.store_translations('fr', mailer_notifier_subject: { ticket_export: subject_bk })
    I18n.backend.store_translations('fr', mailer_notifier: { report_export_mailer: { report_export_task: { cvs_report_request: body_bk } } })
  ensure
    user.destroy if user
  end
end
