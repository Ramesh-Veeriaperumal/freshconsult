# https://confluence.freshworks.com/display/FDCORE/BaseTestHelper+for+BE+Unit+Tests

ENV['RAILS_ENV'] ||= 'test'
$clean_db = false # load fixtures when we bootstrap. use_transactional_fixtures = true is set to roll back every transaction made in each test.

require_relative 'helpers/simple_cov_setup'
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

class ActiveRecord::Base
  mattr_accessor :shared_connection
  @@shared_connection = nil

  def self.connection
    # forcing all threads to share the same connection
    @@shared_connection || retrieve_connection
  end
end

class ActiveSupport::TestCase
  db_config = YAML.safe_load(IO.read(File.join(::Rails.root, 'config/database.yml')))
  new_database = db_config['test_new']['database']

  conn_config = ActiveRecord::Base.connection_config # getting old configuration
  unless conn_config[:database].eql? new_database
    conn_config[:database] = new_database # changing database name
    ActiveRecord::Base.establish_connection conn_config # establishing new connection
  end

  ActiveRecord::Base.shared_connection = ActiveRecord::Base.connection
end
