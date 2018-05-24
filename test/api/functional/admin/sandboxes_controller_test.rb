require_relative '../../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'sandbox_test_helper.rb')

class Admin::SandboxesControllerTest < ActionController::TestCase
  include AccountTestHelper
  include UsersTestHelper
  include SandboxTestHelper
  def setup
    super
    before_all
  end

  def before_all
    @user = create_test_account
    @account = @user.account.make_current
    @user.make_current
    @account.add_feature(:sandbox)
    @account.launch(:sandbox_lp)
  end

  def test_index
    get :index, controller_params({ version: 'private' })
    assert_response 200
  end

  def test_create
    destroy_sandbox_job
    post :create, controller_params({ version: 'private' })
    assert_response 200
  end

  def test_create_with_account_exist
    @account.create_sandbox_job
    post :create, controller_params({ version: 'private' })
    assert_response 403
    destroy_sandbox_job
  end

  def test_destroy_with_sandbox_account
    sandbox_job = @account.create_sandbox_job(:sandbox_account_id => rand(30..40))
    delete :destroy, controller_params({ version: 'private',id: sandbox_job.id } )
    assert_response 204
    destroy_sandbox_job
  end

  def test_create_in_sandbox_account
    @account.mark_as!(:sandbox)
    post :create, controller_params({ version: 'private' }, false)
    assert_response 409
    @account.mark_as!(:production_without_sandbox)
  end

  def test_destroy_without_sandbox_account
    sandbox_job = @account.create_sandbox_job
    delete :destroy, controller_params({ version: 'private',id: sandbox_job.id })
    assert_response 403
    destroy_sandbox_job
  end

  def test_index_without_feature
    @account.revoke_feature(:sandbox)
    get :index, controller_params({ version: 'private' })
    assert_response 403
    @account.add_feature(:sandbox)
  end

  def test_index_with_sandbox_account
    sandbox_job = @account.create_sandbox_job(:sandbox_account_id => rand(30..40))
    get :index, controller_params({ version: 'private' })
    assert_response 200
    match_json(sandbox_index_pattern(sandbox_job))
    destroy_sandbox_job
  end

end
