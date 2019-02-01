require_relative '../../../../api/unit_test_helper'
require 'faker'

class MailProcessorTest < ActionView::TestCase
  include Helpdesk::Email::Migrate

  def setup
    @account = Account.first
    Account.stubs(:current).returns(@account)
    Net::IMAP.any_instance.stubs(:uid_fetch).returns([Net::IMAP::FetchData.new])
    Helpdesk::ProcessEmail.any_instance.stubs(:perform).returns('status' => 'success')
  end

  def teardown
    Account.unstub(:current)
    Net::IMAP.any_instance.unstub(:uid_fetch)
    Helpdesk::ProcessEmail.any_instance.unstub(:perform)
    super
  end

  def construct_args
    imap = Net::IMAP.new('imap.gmail.com', 993, true)
    {
      'account_id' => @account.id,
      'imap' => imap,
      'uid' => 1,
      'raw_eml' => Faker::Internet.email,
      'tags_name' => []
    }
  end

  def test_mail_processor
    response = Helpdesk::Email::Migrate::MailProcessor.new(construct_args).process
    assert_not_nil response
  end

  def test_mail_processor_with_gmail_tags
    args = construct_args
    args['gmail_tags'] = true
    Net::IMAP::FetchData.any_instance.stubs(:attr).returns('X-GM-LABELS' => [:test, :support])
    response = Helpdesk::Email::Migrate::MailProcessor.new(args).process
    assert_not_nil response
  ensure
    Net::IMAP::FetchData.any_instance.unstub(:attr)
  end

  def test_mail_processor_with_migrated_email_ticket
    ticket_params = {
      from: Faker::Internet.email,
      to: Faker::Internet.email,
      subject: Faker::Lorem.characters(10),
      message_id: 1,
      internal_date: '2019-01-26'
    }
    Helpdesk::EmailParser::EmailProcessor.any_instance.stubs(:process_mail).returns(ticket_params)
    Helpdesk::EmailParser::EmailProcessor.any_instance.stubs(:processed_mail).returns(Helpdesk::EmailParser::ProcessedMail.new(Faker::Internet.email))
    Helpdesk::EmailParser::ProcessedMail.any_instance.stubs(:date).returns('2019-01-20')
    Helpdesk::Email::Migrate::MailProcessor.any_instance.stubs(:get_others_redis_key).returns(ticket_params.merge(date: '2019-01-26').except(:internal_date).to_json)
    response = Helpdesk::Email::Migrate::MailProcessor.new(construct_args).process
    assert_not_nil response
  ensure
    Helpdesk::EmailParser::EmailProcessor.any_instance.unstub(:process_mail)
    Helpdesk::EmailParser::EmailProcessor.any_instance.unstub(:processed_mail)
    Helpdesk::EmailParser::ProcessedMail.any_instance.unstub(:date)
    Helpdesk::Email::Migrate::MailProcessor.any_instance.unstub(:get_others_redis_key)
  end

  def test_mail_processor_without_email
    Net::IMAP::FetchData.any_instance.stubs(:attr).returns('RFC822' => Faker::Internet.email)
    response = Helpdesk::Email::Migrate::MailProcessor.new(construct_args.except('raw_eml')).process
    assert_not_nil response
  ensure
    Net::IMAP::FetchData.any_instance.unstub(:attr)
  end
end
