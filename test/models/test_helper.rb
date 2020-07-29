require_relative 'helpers/test_files.rb'
require Rails.root.join('test', 'api', 'helpers', 'test_class_methods.rb')

class ActiveSupport::TestCase
  include TestClassMethods
  def setup
    begin_gc_deferment
    # To Prevent agent central publish error
    Agent.any_instance.stubs(:user_uuid).returns('123456789')
    create_test_account unless @account

    @account ||= Account.first
    @agent ||= get_admin
  end

  def teardown
    reconsider_gc_deferment
    super
    clear_instance_variables
  end

  self.use_transactional_fixtures = false
  fixtures :all
end
