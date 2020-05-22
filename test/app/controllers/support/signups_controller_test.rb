require_relative '../../../api/test_helper'
class Support::SignupsControllerTest < ActionController::TestCase
  include UsersTestHelper
  include CustomFieldsTestHelper

  def setup
    super
  end

  def test_alternate_language_code
    @account.add_feature(:multi_language)
    Support::SignupsController.any_instance.stubs(:set_locale).returns(:ja)
    controller.params[:user] = { name: Faker::Name.name, email: Faker::Internet.email }
    assert_equal 'ja-JP',  controller.safe_send('set_user_language')
  ensure
    Support::SignupsController.any_instance.unstub(:set_locale)
  end

  def test_remove_agent_params
    role_id = @account.roles.first.id
    user_params = { name: Faker::Name.name, email: Faker::Internet.email }
    controller.params[:user] = user_params.merge(helpdesk_agent: 1, role_ids: [role_id.to_s])
    assert_equal user_params.stringify_keys, controller.safe_send('remove_agent_params')
  end
end
