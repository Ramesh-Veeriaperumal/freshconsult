require_relative '../../../../api/unit_test_helper'
require 'faker'

class ImapMigrationTest < ActionView::TestCase
  include Helpdesk::Email::Migrate

  def setup
    @account = Account.first
    Account.stubs(:current).returns(@account)
    Net::IMAP.any_instance.stubs(:login).returns(true)
    Net::IMAP.any_instance.stubs(:logout).returns(true)
    Net::IMAP.any_instance.stubs(:disconnect).returns(true)
    Net::IMAP.any_instance.stubs(:examine).returns(true)
    Net::IMAP.any_instance.stubs(:uid_fetch).returns([Net::IMAP::FetchData.new])
    Net::IMAP::FetchData.any_instance.stubs(:attr).returns(Faker::Lorem.characters(10))
    Helpdesk::Email::Migrate::Mailer.any_instance.stubs(:send_mail).returns(true)
    Helpdesk::Email::Migrate::MailProcessor.any_instance.stubs(:process).returns({})
    Helpdesk::Email::Migrate::ImapMigration.any_instance.stubs(:sleep).returns(true)
  end

  def teardown
    Account.unstub(:current)
    Net::IMAP.any_instance.unstub(:login)
    Net::IMAP.any_instance.unstub(:logout)
    Net::IMAP.any_instance.unstub(:disconnect)
    Net::IMAP.any_instance.unstub(:examine)
    Net::IMAP.any_instance.unstub(:uid_fetch)
    Net::IMAP::FetchData.any_instance.unstub(:attr)
    Helpdesk::Email::Migrate::Mailer.unstub.stubs(:send_mail)
    Helpdesk::Email::Migrate::MailProcessor.any_instance.unstub(:process)
    Helpdesk::Email::Migrate::ImapMigration.any_instance.unstub(:sleep)
    super
  end

  def construct_args
    {
      'user_name' => Faker::Internet.email,
      'password' => Faker::Lorem.characters(10),
      'notify_email' => Faker::Internet.email,
      'envelope_address' => Faker::Internet.email,
      'server_name' => 'imap.gmail.com',
      'folder' => 'INBOX',
      'tags_name' => 'email_import',
      'gmail_tags' => false,
      'start_time' => '25-Jan-2019 10:10:10 +0000',
      'end_time' => '27-Jan-2019 10:10:10 +0000',
      'account_id' => @account.id,
      'email_config_id' => Faker::Number.number(10)
    }
  end

  def test_imap_migration
    Net::IMAP.any_instance.stubs(:uid_search).returns([])
    response = Helpdesk::Email::Migrate::ImapMigration.new(construct_args).process
  ensure
    Net::IMAP.any_instance.unstub(:uid_search)
  end

  def test_imap_migration_without_mandatory_data
    args = construct_args
    Net::IMAP.any_instance.stubs(:uid_search).returns([])
    response = Helpdesk::Email::Migrate::ImapMigration.new(args.except('email_config_id')).process
  end

  def test_imap_migration_with_null_imap
    args = construct_args
    args['uid_array'] = ['12', '11']
    Helpdesk::Email::Migrate::ImapMigration.any_instance.stubs(:uids_list).returns(Net::IMAP.any_instance.stubs(:nil?).returns(true))
    response = Helpdesk::Email::Migrate::ImapMigration.new(args).process
  ensure
    Helpdesk::Email::Migrate::ImapMigration.any_instance.unstub(:uids_list)
    Net::IMAP.any_instance.unstub(:nil?)
  end

  def test_imap_migration_with_authentication
    args = construct_args
    args['authentication'] = true
    Net::IMAP.any_instance.stubs(:uid_search).returns([])
    Net::IMAP.any_instance.stubs(:authenticate).returns(true)
    response = Helpdesk::Email::Migrate::ImapMigration.new(args).process
  ensure
    Net::IMAP.any_instance.unstub(:uid_search)
    Net::IMAP.any_instance.unstub(:authenticate)
  end

  def test_imap_migration_with_uids_from_search
    Net::IMAP.any_instance.stubs(:uid_search).returns(['90'])
    Net::IMAP::FetchData.any_instance.stubs(:attr).returns('INTERNALDATE' => '26-Jan-2019 10:10:10 +0000')
    response = Helpdesk::Email::Migrate::ImapMigration.new(construct_args).process
  ensure
    Net::IMAP.any_instance.unstub(:uid_search)
    Net::IMAP::FetchData.any_instance.unstub(:attr)
  end

  def test_imap_migration_with_uids_from_customer
    args = construct_args
    args['uid_array'] = ['12', '11']
    response = Helpdesk::Email::Migrate::ImapMigration.new(args).process
  end

  def test_imap_migration_errors_on_connection_timeout
    Timeout.stubs(:timeout).raises(Timeout::Error)
    response = Helpdesk::Email::Migrate::ImapMigration.new(construct_args).process
  rescue Timeout::Error => e
    assert_nil response
  ensure
    Timeout.unstub(:timeout)
  end

  def test_imap_migration_errors_out_on_exceptions
    Net::IMAP.any_instance.stubs(:uid_search).returns(['90'])
    response = Helpdesk::Email::Migrate::ImapMigration.new(construct_args).process
  ensure
    Net::IMAP.any_instance.unstub(:uid_search)
  end

  def test_imap_migration_errors_out_during_mail_processor_exception
    Net::IMAP.any_instance.stubs(:uid_search).returns(['90'])
    Net::IMAP::FetchData.any_instance.stubs(:attr).returns('INTERNALDATE' => '26-Jan-2019 10:10:10 +0000')
    Helpdesk::Email::Migrate::MailProcessor.any_instance.stubs(:process).raises(Exception)
    response = Helpdesk::Email::Migrate::ImapMigration.new(construct_args).process
  ensure
    Net::IMAP.any_instance.unstub(:uid_search)
    Net::IMAP::FetchData.any_instance.unstub(:attr)
    Helpdesk::Email::Migrate::MailProcessor.any_instance.unstub(:process)
  end
end
