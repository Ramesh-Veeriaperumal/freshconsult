# frozen_string_literal: true

require_relative '../../../api/test_helper'

class Admin::RolesControllerTest < ActionController::TestCase
  include AccountHelper

  def setup
    super
    @account = Account.first || create_test_account
    @account.make_current
  end

  def test_manage_account_on_create_without_proper_ability
    Account.any_instance.stubs(:current).returns(@account)
    abilities_without_manage_account = User.current.abilities - [:manage_account]
    User.any_instance.stubs(:abilities).returns(abilities_without_manage_account)
    name = "Test Role Param - #{Time.now.utc}"
    post :create, construct_params(roles_params(name: name))
    assert_response 302
    role = Account.current.roles.find_by_name(name)
    assert_equal true, role.privilege?(:admin_tasks)
    assert_equal false, role.privilege?(:manage_account)
  ensure
    role.try(:destroy)
    User.any_instance.unstub(:abilities)
    Account.any_instance.unstub(:current)
  end

  def test_manage_account_on_update_without_proper_ability
    Account.any_instance.stubs(:current).returns(@account)
    name = "Test Role Param - #{Time.now.utc}"
    role_save_params = roles_params(name: name, list: ['admin_tasks'])
    roles = @account.roles.build(role_save_params[:role])
    roles.save
    abilities_without_manage_account = User.current.abilities - [:manage_account]
    User.any_instance.stubs(:abilities).returns(abilities_without_manage_account)
    put :update, construct_params({ id: roles.id }.merge!(roles_params(name: name)))
    assert_response 302
    role = Account.current.roles.find_by_name(name)
    assert_equal true, role.privilege?(:admin_tasks)
    assert_equal false, role.privilege?(:manage_account)
    assert_equal true, role.privilege?(:manage_users)
  ensure
    role.try(:destroy)
    User.any_instance.unstub(:abilities)
    Account.any_instance.unstub(:current)
  end

  def test_manage_account_on_create_with_proper_ability
    Account.any_instance.stubs(:current).returns(@account)
    abilities_without_manage_account = User.current.abilities
    abilities_without_manage_account += [:manage_account] unless abilities_without_manage_account.include?(:manage_account)
    User.any_instance.stubs(:abilities).returns(abilities_without_manage_account)
    name = "Test Role Param - #{Time.now.utc}"
    post :create, construct_params(roles_params(name: name))
    assert_response 302
    role = Account.current.roles.find_by_name(name)
    assert_equal true, role.privilege?(:admin_tasks)
    assert_equal true, role.privilege?(:manage_account)
  ensure
    role.try(:destroy)
    User.any_instance.unstub(:abilities)
    Account.any_instance.unstub(:current)
  end

  def test_manage_account_on_update_with_proper_ability
    Account.any_instance.stubs(:current).returns(@account)
    name = "Test Role Param - #{Time.now.utc}"
    role_save_params = roles_params(name: name, list: ['admin_tasks'])
    roles = @account.roles.build(role_save_params[:role])
    roles.save
    abilities_without_manage_account = User.current.abilities
    abilities_without_manage_account += [:manage_account] unless abilities_without_manage_account.include?(:manage_account)
    User.any_instance.stubs(:abilities).returns(abilities_without_manage_account)
    put :update, construct_params({ id: roles.id }.merge!(roles_params(name: name)))
    assert_response 302
    role = Account.current.roles.find_by_name(name)
    assert_equal true, role.privilege?(:admin_tasks)
    assert_equal true, role.privilege?(:manage_account)
    assert_equal true, role.privilege?(:manage_users)
  ensure
    role.try(:destroy)
    User.any_instance.unstub(:abilities)
    Account.any_instance.unstub(:current)
  end

  def test_new_role_when_max_limit_reached
    stub_const(RoleConstants, 'MAX_ROLES_LIMIT', 1) do
      get :new, format: 'html'
      assert_response 302
      assert_equal true, Account.current.roles.count.positive?
      assert_includes response.redirect_url, '/admin/roles'
    end
  end

  def test_new_role_when_max_limit_not_reached
    get :new, format: 'html'
    assert_response 200
    assert_equal true, Account.current.roles.count < RoleConstants::MAX_ROLES_LIMIT
  end

  def test_index_when_max_limit_reached
    stub_const(RoleConstants, 'MAX_ROLES_LIMIT', 1) do
      get :index, format: 'html'
      assert_response 200
      assert_equal true, Account.current.roles.count.positive?
      assert_equal true, @controller.safe_send(:max_limit_reached?)
    end
  end

  def test_index_when_max_limit_not_reached
    get :index, format: 'html'
    assert_response 200
    assert_equal true, Account.current.roles.count < RoleConstants::MAX_ROLES_LIMIT
    assert_equal false, @controller.safe_send(:max_limit_reached?)
  end

  def test_create_when_max_limit_reached
    stub_const(RoleConstants, 'MAX_ROLES_LIMIT', 1) do
      name = "Test Role Param - #{Time.now.utc}"
      post :create, construct_params(roles_params(name: name))
      assert_response 302
      role = Account.current.roles.find_by_name(name)
      assert_equal false, role.present?
      assert_includes response.redirect_url, '/admin/roles'
      assert_equal true, Account.current.roles.count.positive?
      assert_equal true, @controller.safe_send(:max_limit_reached?)
    end
  end

  private

    def roles_params(args = {})
      {
        format: 'html',
        role: {
          name: args[:name],
          description: 'A Sample Test Role',
          privilege_list: args[:list] || [+'admin_tasks', +'manage_account', +'manage_users']
        },
        add_user_ids: '',
        delete_user_ids: ''
      }
    end
end
