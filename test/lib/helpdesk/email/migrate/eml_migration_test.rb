require_relative '../../../../api/unit_test_helper'
require 'faker'

class EmailMigrationTest < ActionView::TestCase
  include Helpdesk::Email::Migrate

  def setup
    @account = Account.first
    Account.stubs(:current).returns(@account)
    @email_config = @account.email_configs.first
    Helpdesk::Email::Migrate::Mailer.any_instance.stubs(:send_mail).returns(true)
    Helpdesk::Email::Migrate::MailProcessor.any_instance.stubs(:process).returns({})
  end

  def teardown
    Account.unstub(:current)
    Helpdesk::Email::Migrate::Mailer.any_instance.unstub(:send_mail)
    Helpdesk::Email::Migrate::MailProcessor.any_instance.unstub(:process)
    super
  end

  def construct_args
    {
      'file_path' => File.new(Rails.root.join('test', 'api', 'fixtures', 'files', 'attachment.zip')).path,
      'envelope_address' => Faker::Internet.email,
      'notify_email' => Faker::Internet.email,
      'account_id' => @account.id,
      'email_config_id' => @email_config.id
    }
  end

  def test_email_migration_without_mandatory_arguments
    response = Helpdesk::Email::Migrate::EmlMigration.new(construct_args.except('email_config_id')).process
    assert_nil response
  end

  def test_email_migration_with_mandatory_arguments
    Zip::Entry.any_instance.stubs(:get_input_stream).returns(Zip::Entry.new)
    Zip::Entry.any_instance.stubs(:read).returns(Faker::Lorem.characters(10))
    response = Helpdesk::Email::Migrate::EmlMigration.new(construct_args).process
    assert_not_nil response
  ensure
    Zip::Entry.any_instance.unstub(:get_input_stream)
    Zip::Entry.any_instance.unstub(:read)
  end

  def test_email_migration_errors_during_file_handling
    Zip::File.stubs(:open).raises(Exception)
    response = Helpdesk::Email::Migrate::EmlMigration.new(construct_args).process
    assert_not_nil response
  ensure
    Zip::File.unstub(:open)
  end

  def test_email_migration_errors_during_file_operations
    Zip::Entry.any_instance.stubs(:get_input_stream).returns(Zip::Entry.new)
    Zip::Entry.any_instance.stubs(:read).returns(Faker::Lorem.characters(10))
    Helpdesk::Email::Migrate::MailProcessor.any_instance.stubs(:process).raises(Exception)
    response = Helpdesk::Email::Migrate::EmlMigration.new(construct_args).process
    assert_not_nil response
  ensure
    Zip::Entry.any_instance.unstub(:get_input_stream)
    Zip::Entry.any_instance.unstub(:read)
    Helpdesk::Email::Migrate::MailProcessor.any_instance.unstub(:process)
  end
end
