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
end
