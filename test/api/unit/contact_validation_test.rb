require_relative '../unit_test_helper'

class ContactValidationTest < ActionView::TestCase
  def tear_down
    Account.unstub(:current)
    super
  end

  def test_tags_comma_invalid
    Account.stubs(:current).returns(Account.first)
    controller_params = { 'name' => 'test', :email => Faker::Internet.email, tags: ['comma,test'] }
    item = nil
    contact = ContactValidation.new(controller_params, item)
    refute contact.valid?
    errors = contact.errors.full_messages
    assert errors.include?('Tags special_chars_present')
    Account.unstub(:current)
  end

  def test_tags_comma_valid
    Account.stubs(:current).returns(Account.first)
    controller_params = { 'name' => 'test', :email => Faker::Internet.email, tags: ['comma', 'test'] }
    item = nil
    contact = ContactValidation.new(controller_params, item)
    assert contact.valid?
    Account.unstub(:current)
  end

  def test_tags_multiple_errors
    Account.stubs(:current).returns(Account.first)
    controller_params = { 'name' => 'test', :email => Faker::Internet.email, tags: 'comma,test' }
    item = nil
    contact = ContactValidation.new(controller_params, item)
    refute contact.valid?
    errors = contact.errors.full_messages
    assert errors.include?('Tags data_type_mismatch')
    assert errors.count == 1
    Account.unstub(:current)
  end

  def test_avatar_multiple_errors
    Account.stubs(:current).returns(Account.first)
    String.any_instance.stubs(:size).returns(20_000_000)
    controller_params = { 'name' => 'test', :email => Faker::Internet.email, avatar: 'file.png' }
    item = nil
    contact = ContactValidation.new(controller_params, item)
    refute contact.valid?
    errors = contact.errors.full_messages
    assert errors.include?('Avatar data_type_mismatch')
    assert errors.count == 1
    Account.unstub(:current)
  end
end
