require_relative 'helpers/test_files.rb'
require Rails.root.join('test', 'api', 'helpers', 'test_class_methods.rb')

class ActiveSupport::TestCase
  include TestClassMethods
  def setup
    begin_gc_deferment
    ChargeBee::Customer.stubs(:update).returns(true)
    create_test_account unless @account

    @account ||= Account.first
    @agent ||= get_admin
  end

  def teardown
    reconsider_gc_deferment
    super
    ChargeBee::Customer.unstub(:update)
    clear_instance_variables
  end

  self.use_transactional_fixtures = false
  fixtures :all
end
