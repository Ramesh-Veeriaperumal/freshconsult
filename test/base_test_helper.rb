ENV['RAILS_ENV'] ||= 'test'
$clean_db = false # load fixtures when we bootstrap. use_transactional_fixtures = true is set to roll back every transaction made in each test.

require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

class ActiveRecord::Base
  mattr_accessor :shared_connection
  @@shared_connection = nil

  def self.connection
    @@shared_connection || retrieve_connection
  end
end

class ActiveSupport::TestCase
  self.use_transactional_fixtures = true
  ActiveRecord::Base.shared_connection = ActiveRecord::Base.connection
end

class ActionController::TestCase
  self.use_transactional_fixtures = true
  ActiveRecord::Base.shared_connection = ActiveRecord::Base.connection
end

class ActionDispatch::IntegrationTest
  self.use_transactional_fixtures = true
  ActiveRecord::Base.shared_connection = ActiveRecord::Base.connection
end

class ActionView::TestCase
  self.use_transactional_fixtures = true
  ActiveRecord::Base.shared_connection = ActiveRecord::Base.connection
end