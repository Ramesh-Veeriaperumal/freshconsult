require 'resque/tasks'
require 'resque_scheduler/tasks'
namespace :resque do
  task :setup => :environment do
    ['shard_mappings','domain_mappings'].each do |table_name|
      ActiveRecord::Base.connection.schema_cache.columns_hash[table_name]
    end
  end
end