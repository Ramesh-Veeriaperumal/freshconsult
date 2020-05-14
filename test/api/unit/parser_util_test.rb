require_relative '../unit_test_helper'

class EmailParserTest < ActionView::TestCase
  include ParserUtil

  def test_parse_emails_with_new_regex
    Account.stubs(:current).returns(Account.first || create_test_account)
    Account.any_instance.stubs(:new_email_regex_enabled?).returns(true)
    addresses = parse_addresses(['test.@gmail.com', 'test[@gmail.com', 'a.b@c.com', 'test@gmail.com'],{})
    assert addresses[:emails].include?('a.b@c.com')
    assert addresses[:emails].include?('test@gmail.com')
    refute addresses[:emails].include?('test.@gmail.com')
    refute addresses[:emails].include?('test[@gmail.com')
  ensure
    Account.any_instance.unstub(:new_email_regex_enabled?)
    Account.unstub(:current)
  end

  def test_parse_emails_with_old_regex
    addresses = parse_addresses(['test.@gmail.com', 'test[@gmail.com', 'a.b@c.com', 'test@gmail.com'],{})
    assert addresses[:emails].include?('a.b@c.com')
    assert addresses[:emails].include?('test@gmail.com')
    assert addresses[:emails].include?('test.@gmail.com')
    refute addresses[:emails].include?('test[@gmail.com')
  end

  def test_fetch_valid_emails_old_regex
    addresses = fetch_valid_emails_without_mail_parser(['test.@gmail.com', 'test[@gmail.com', 'a.b@c.com', 'test@gmail.com'],{})
    assert addresses.include?('a.b@c.com')
    assert addresses.include?('test@gmail.com')
    assert addresses.include?('test.@gmail.com')
    refute addresses.include?('test[@gmail.com')
  end

  def test_fetch_valid_emails_new_regex
    Account.stubs(:current).returns(Account.first || create_test_account)
    Account.any_instance.stubs(:new_email_regex_enabled?).returns(true)
    addresses = fetch_valid_emails_without_mail_parser(['test.@gmail.com', 'test[@gmail.com', 'a.b@c.com', 'test@gmail.com'],{})
    assert addresses.include?('a.b@c.com')
    assert addresses.include?('test@gmail.com')
    refute addresses.include?('test.@gmail.com')
    refute addresses.include?('test[@gmail.com')
  ensure
    Account.any_instance.unstub(:new_email_regex_enabled?)
    Account.unstub(:current)
  end
end
