require_relative '../test_helper'
require 'minitest/spec'
class EmailValidatorTest < ActiveSupport::TestCase
  class EmailRegexValidation
    include ActiveModel::Validations
    attr_accessor :email_a, :email_b, :email_c, :email_d, :email_e, :error_options

    def initialize(*_args)
      @error_options = {}
    end

    validates_format_of :email_a, with: proc { AccountConstants.named_email_validator }, message: I18n.t('activerecord.errors.messages.invalid'), allow_nil: true
    validates_format_of :email_b, with: proc { AccountConstants.email_validator }, message: I18n.t('activerecord.errors.messages.invalid'), allow_nil: true
    validates_format_of :email_c, with: proc { AccountConstants.email_regex }, message: I18n.t('activerecord.errors.messages.invalid'), allow_nil: true
    validates_format_of :email_d, with: proc { AccountConstants.email_scanner }, message: I18n.t('activerecord.errors.messages.invalid'), allow_nil: true
    validates_format_of :email_e, with: proc { AccountConstants.authlogic_email_regex }, message: I18n.t('activerecord.errors.messages.invalid'), allow_nil: true
  end

  def test_valid_emails
    Account.stubs(:current).returns(Account.first || create_test_account)
    Account.any_instance.stubs(:new_email_regex_enabled?).returns(true)
    test = EmailRegexValidation.new
    emails = %w[a.b.c@gmail.com a_b_c@gmail.com a@b.com b@gmail.com test@gmail.com abc<a.b.c@gmail.com> abc<a_b@gmail.com> <!--test@gmail.com-->]

    emails.each do |email|
      test.email_a = email
      assert test.valid?
    end

    emails = %w[a.b.c@gmail.com a_b_c@gmail.com a@b.com b@gmail.com test@gmail.com]

    emails.each do |email|
      test.email_b = email
      assert test.valid?
    end

    emails.each do |email|
      test.email_c = email
      assert test.valid?
    end

    emails.each do |email|
      test.email_d = email
      assert test.valid?
    end

    emails.each do |email|
      test.email_e = email
      assert test.valid?
    end
  ensure
    Account.any_instance.unstub(:new_email_regex_enabled?)
    Account.unstub(:current)
  end

  def test_invalid_emails_new_regex
    Account.stubs(:current).returns(Account.first || create_test_account)
    Account.any_instance.stubs(:new_email_regex_enabled?).returns(true)
    test = EmailRegexValidation.new
    emails = %w(a_b_c.@gmail.com a>@b.com b(@gmail.com test)@gmail.com abc<a.b.c;@gmail.com> abc<a_b:@gmail.com> <!--test()@gmail.com-->)
    emails.each do |email|
      test.email_a = email
      refute test.valid?
    end
    test.email_a = nil

    emails = %w(a_b_c.@gmail.com a>@b.com b(@gmail.com test)@gmail.com)

    emails.each do |email|
      test.email_b = email
      refute test.valid?
    end
    test.email_b = nil

    emails.each do |email|
      test.email_c = email
      refute test.valid?
    end
    test.email_c = nil

    emails.each do |email|
      test.email_d = email
      refute test.valid?
    end
    test.email_d = nil

    emails.each do |email|
      test.email_e = email
      refute test.valid?
    end
  ensure
    Account.any_instance.unstub(:new_email_regex_enabled?)
    Account.unstub(:current)
  end

  def test_invalid_emails_old_regex
    Account.stubs(:current).returns(Account.first || create_test_account)
    Account.any_instance.stubs(:new_email_regex_enabled?).returns(false)
    test = EmailRegexValidation.new
    emails = %w(a>@b.com b(@gmail.com test)@gmail.com abc<a.b.c;@gmail.com> abc<a_b:@gmail.com> <!--test()@gmail.com-->)
    emails.each do |email|
      test.email_a = email
      refute test.valid?
    end
    test.email_a = nil

    emails = %w(a>@b.com b(@gmail.com test)@gmail.com)

    emails.each do |email|
      test.email_b = email
      refute test.valid?
    end
    test.email_b = nil

    emails.each do |email|
      test.email_c = email
      refute test.valid?
    end
    test.email_c = nil

    emails.each do |email|
      test.email_d = email
      refute test.valid?
    end
    test.email_d = nil

    emails.each do |email|
      test.email_e = email
      refute test.valid?
    end
  ensure
    Account.any_instance.unstub(:new_email_regex_enabled?)
    Account.unstub(:current)
  end
end
