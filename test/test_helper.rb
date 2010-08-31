ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'
require 'shoulda'
require 'mocha'


class ActionController::TestCase
  def allow_all
    @controller.stubs(:permission?).returns(true)
  end

  def deny_all
    @controller.stubs(:permission?).returns(false)
  end

  def stub_user
    @user = User.first
    @user.login = "joey"
    @user.name = "Joe Bob"
    @controller.stubs(:current_user).returns(@user)
  end

  def set_referrer
    @request.env['HTTP_REFERER'] = eval(ActionController::TestCase.back)
  end

  def self.back
    "'http://referrer'"
  end

  def publicize_controller_methods
    @protected_methods = @controller.class.protected_instance_methods
    @private_methods = @controller.class.private_instance_methods
    @controller.class.send(:public, *@protected_methods)  
    @controller.class.send(:public, *@private_methods)
  end

  def privatize_controller_methods
    @controller.class.send(:private, *@private_methods)  
    @controller.class.send(:protected, *@protected_methods)
  end

  def self.should_not_show_form_errors
    should "not show form errors" do
      assert_select "#errorExplanation", false
    end
  end

  def self.should_show_form_errors
    should "show form errors" do
      assert_select "#errorExplanation"
    end
  end
  
end

class ActiveSupport::TestCase
  # Transactional fixtures accelerate your tests by wrapping each test method
  # in a transaction that's rolled back on completion.  This ensures that the
  # test database remains unchanged so your fixtures don't have to be reloaded
  # between every test method.  Fewer database queries means faster tests.
  #
  # Read Mike Clark's excellent walkthrough at
  #   http://clarkware.com/cgi/blosxom/2005/10/24#Rails10FastTesting
  #
  # Every Active Record database supports transactions except MyISAM tables
  # in MySQL.  Turn off transactional fixtures in this case; however, if you
  # don't care one way or the other, switching from MyISAM to InnoDB tables
  # is recommended.
  #
  # The only drawback to using transactional fixtures is when you actually 
  # need to test transactions.  Since your test is bracketed by a transaction,
  # any transactions started in your code will be automatically rolled back.
  self.use_transactional_fixtures = true

  # Instantiated fixtures are slow, but give you @david where otherwise you
  # would need people(:david).  If you don't want to migrate your existing
  # test cases which use the @david style and don't mind the speed hit (each
  # instantiated fixtures translates to a database query per test method),
  # then set this back to true.
  self.use_instantiated_fixtures  = false

  # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  # Add more helper methods to be used by all tests here...
  
  def self.should_have_attached_file(attachment)
    klass = self.name.gsub(/Test$/, '').constantize

    context "To support a paperclip attachment named #{attachment}, #{klass}" do
      should_have_db_column("#{attachment}_file_name",    :type => :string)
      should_have_db_column("#{attachment}_content_type", :type => :string)
      should_have_db_column("#{attachment}_file_size",    :type => :integer)
    end

    should "have a paperclip attachment named ##{attachment}" do
      assert klass.new.respond_to?(attachment.to_sym), 
             "@#{klass.name.underscore} doesn't have a paperclip field named #{attachment}"
      assert_equal Paperclip::Attachment, klass.new.send(attachment.to_sym).class
    end
  end
end


# We have to patch shoulda, because it doesn't handle namespaced models well.
# klass.to_s.underscore results in "helpdesk/ticket", when we just need "ticket"

module ThoughtBot # :nodoc:
  module Shoulda # :nodoc:
    module ActiveRecord # :nodoc:
      module Assertions
        def get_instance_of(object_or_klass)
          if object_or_klass.is_a?(Class)
            klass = object_or_klass
            instance_variable_get("@#{klass.to_s.underscore.split('/')[-1]}") || klass.new
          else
            object_or_klass
          end
        end
      end
    end
  end
end
