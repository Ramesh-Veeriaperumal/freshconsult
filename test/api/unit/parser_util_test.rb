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

  def test_memcache_keys_from_yaml
    key = MemcacheKeys.key(:'source_account_choice_id.account_id', 1234)
    assert_equal key, 'v1/ACCOUNT_SOURCES:1234'

    key = MemcacheKeys.key2(:'componse_email_form.account_id.language', 1234, :en)
    assert_equal key, 'v3/COMPOSE_EMAIL_FORM:1234:en'

    key = MemcacheKeys.key3(:'dummy', 1234, :en, :product)
    assert_equal key, 'dummy:1234:en:product'

    key = MemcacheKeys.key4(:'dummy', 1234, :en, :product, '2020')
    assert_equal key, 'dummy:1234:en:product:2020'
  end
end
