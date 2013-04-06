require 'tire/tasks'
require 'lib/memcache_keys.rb'
include MemcacheKeys

namespace :freshdesk_tire do

  generic_comment = <<-DESC
    - Important Note
      * Passing of CLASS variable is optional.
      * If no CLASS variable is passed to the rake task, then all the indexed classes for the
        account ids will be imported.
      * If you want the task to be run for multiple classes, specify CLASSES seperated by a ','
        in the CLASS variable
        $ rake freshdesk_tire:<task_name> CLASS='Article,Comment'
  DESC

  create_index_comment = <<-DESC
    - Create index task aborted!!!

      * Minimum number of account ids to be specified = 1
      * If you want the task to be run for multiple accounts specify account ids seperated by a ','
        in the ACCOUNT_ID variable
        $ rake freshdesk_tire:create_index ACCOUNT_ID='Id/Ids' CLASS='Article'
  DESC

  delete_indices_comment = <<-DESC
    - Delete indices task aborted!!!
      * Delete indices passed in the INDICES environment variable; separate multiple indices by comma.
      * Pass names of single/multiple indices to drop in the INDICES environmnet variable:
        $ rake freshdesk_tire:delete_indices INDICES=articles-2011-01,articles-2011-02
  DESC

  reindex_comment = <<-DESC
    - Reindex task aborted!!!
      * Minimum number of account ids to be specified = 1
      * If you want the task to be run for multiple accounts specify account ids seperated by a ','
        in the ACCOUNT_ID variable
        $ rake freshdesk_tire:reindex ACCOUNT_ID='Id/Ids'
  DESC

  desc 'Create elasticsearch index and import data to index'

  task :create_index  => :environment do
    begin
      puts generic_comment
      es_account_ids = ENV['ACCOUNT_ID'].split(',')
      init_es_indexing(es_account_ids)
    rescue
      puts '='*100, ' '*45+'USAGE', '='*100, create_index_comment, ""
    end
  end

  task :create_index_predefined => :environment do
    puts generic_comment
    es_account_ids = EsEnabledAccount.all.collect {|p| p.account_id}
    init_reindex(es_account_ids)
  end

  task :multi_class_import => :environment do
    account = Account.find_by_id(ENV['ACCOUNT_ID'])
    account.make_current
    account.es_enabled_account.switch_to_sphinx
    SeamlessDatabasePool.use_persistent_read_connection do
      klasses = ENV['CLASS'].split(';')
      klasses.each do |klass|
        ENV['CLASS'] = klass
        Rake::Task["tire:import"].execute("CLASS='#{ENV['CLASS']}' INDEX=#{ENV['INDEX']}")
      end
    end
    account.es_enabled_account.switch_to_es
    Account.reset_current_account
  end

  task :delete_indices => :environment do
    if ENV['INDICES'].blank?
      puts '='*100, ' '*45+'USAGE', '='*100, delete_indices_comment, ""
      exit(1)
    end
    Rake::Task["tire:index:drop"].execute("INDICES=#{ENV['INDICES']}")
  end

  task :reindex => :environment do
    if ENV['ACCOUNT_ID'].blank?
      puts '='*100, ' '*45+'USAGE', '='*100, reindex_comment, ""
      exit(1)
    end
    es_account_ids = ENV['ACCOUNT_ID'].split(',')
    init_reindex(es_account_ids)
  end
end

def init_es_indexing(es_account_ids)
  klasses = ENV['CLASS']
  existing_accounts = Array.new
  es_account_ids.each do |account_id|
    account = Account.find_by_id(account_id)
    account.make_current
    if account.es_enabled_account.nil?
      account.enable_elastic_search
      account.create_search_index
      ENV['INDEX'] = account.search_index_name
      ENV['CLASS'] = import_classes(account_id, klasses)
      Rake::Task["freshdesk_tire:multi_class_import"].execute("CLASS='#{ENV['CLASS']}' INDEX=#{ENV['INDEX']} ACCOUNT_ID=#{account_id}")
    else
      puts '='*100, ' '*10+"Index already exists for Account ID: #{account_id}. Please use reindex task for Account ID: #{account_id}", '='*100, ""
      existing_accounts.push(account_id)
    end
    Account.reset_current_account
  end
  puts '='*100, ' '*10+"Index already exists for following accounts: #{existing_accounts.inspect}. You can use reindex task to index the same", '='*100, "" unless existing_accounts.blank?
end

def init_reindex(es_account_ids)
  if es_account_ids.blank?
    puts '='*100, ' '*45+'No predefined es-accounts available.', '='*100, ""
    exit(1)
  end
  es_account_ids.each do |account_id|
    account = Account.find_by_id(account_id)
    account.make_current
    ENV['INDICES'] = account.search_index_name
    ENV['ACCOUNT_ID'] = account_id.to_s
    unless account.es_enabled_account.nil?
      if account.es_enabled?
        account.es_enabled_account.disable_elastic_search
        Rake::Task["tire:index:drop"].execute("INDICES=#{ENV['INDICES']}")
        Rake::Task["freshdesk_tire:create_index"].execute("ACCOUNT_ID=#{ENV['ACCOUNT_ID']}")
      else
        puts '='*100, ' '*10+"Import already running for Account ID: #{account_id}. Cancelled reindex for Account: #{account_id}", '='*100, ""
      end
    else
      Rake::Task["freshdesk_tire:create_index"].execute("ACCOUNT_ID=#{ENV['ACCOUNT_ID']}")
    end
    Account.reset_current_account
  end
end

def import_classes(id, klasses)
  import_classes = klasses.blank? ? ['User', 'Helpdesk::Ticket', 'Solution::Article', 'Topic', 'Customer'] : klasses.split(',')
  import_classes.collect!{ |item| "#{item}#{import_condition(id, item)}" }.join(';')
end

def import_condition(id, item)
  condition = ".scoped(:conditions => ['account_id=? and updated_at<?', #{id}, Time.now.utc])"
  case item.strip
    when "Helpdesk::Ticket" then
      condition = ".scoped(:conditions => ['account_id=? and updated_at<? and deleted=? and spam=?', #{id}, Time.now.utc, false, false])"
    when "User" then
      condition = ".scoped(:conditions => ['account_id=? and updated_at<? and deleted=?', #{id}, Time.now.utc, false])"
  end
  condition
end
