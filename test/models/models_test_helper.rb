# https://confluence.freshworks.com/display/FDCORE/BaseTestHelper+for+BE+Unit+Tests

require_relative '../base_test_helper.rb'
require_relative 'helpers/test_files.rb'
require Rails.root.join('test', 'api', 'helpers', 'test_class_methods.rb')

class ActiveSupport::TestCase
  include TestClassMethods

  def setup
    self.use_transactional_fixtures = true

    $redis_others.flushall # redis cleanup
    WebMock.disable_net_connect! # disabling Webmock

    begin_gc_deferment
    create_test_account unless @account
    @account ||= Account.first
    @agent ||= get_admin
  end

  def teardown
    reconsider_gc_deferment
    super
    clear_instance_variables
  end

end
