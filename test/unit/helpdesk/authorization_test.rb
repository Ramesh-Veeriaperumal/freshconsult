require 'test_helper'

class Helpdesk::AuthorizationTest < ActiveSupport::TestCase
  should_belong_to :user
  should_have_class_methods :find_all_by_permission
  should_have_instance_methods :role, :name, :permission?
  should_validate_presence_of :role_token, :user_id
  should_have_index :role_token, :user_id

  should "Have required contants" do
    assert Helpdesk::Authorization::ROLE_OPTIONS
  end

  context "New authorization" do
    setup { @auth = Helpdesk::Authorization.new }

    should "Return user's name when @auth.name called" do
      user = mock
      user.expects(:name).returns("bob")
      @auth.expects(:user).returns(user)
      assert_equal "bob", @auth.name
    end

    should "Return the appropriate role hash when @auth.role called and valid role_token" do
      Helpdesk::ROLES.each do |k, v|
        a = Helpdesk::Authorization.new
        a.expects(:role_token).returns(k)
        assert_equal v, a.role
      end
    end

    should "Return the 'customer' role hash when @auth.role called with invalid role_token" do
      @auth.expects(:role_token).returns(:not_a_valid_role_token)
      assert_equal Helpdesk::ROLES[:customer], @auth.role
    end

    should "Return a boolean indicating if the authorization grants a specific permission" do
      @auth.expects(:role).returns({:permissions => {:breathe => true}})
      assert @auth.permission?(:breathe)
      @auth.expects(:role).returns({:permissions => {:spit => false}})
      assert !@auth.permission?(:spit)
      @auth.expects(:role).returns({:permissions => {}})
      assert !@auth.permission?(:something_else)
    end
  end
end
