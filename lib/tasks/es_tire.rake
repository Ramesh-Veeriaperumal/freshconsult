require 'tire/tasks'

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
        $ rake freshdesk_tire:create_index ACCOUNT_ID='Id/Ids'
  DESC

  class_import_comment = <<-DESC
    - Class import task aborted!!!

      * The class import runs with a default condition. If you want to manually specify condition please use
        multi_class_import task. (The multi_class_import task can be done for one account at a time)
      * Minimum number of account ids to be specified = 1
      * Minimum number of classes to be specified = 1
      * If you want the task to be run for multiple accounts specify account ids seperated by a ','
        in the ACCOUNT_ID variable
        $ rake freshdesk_tire:class_import ACCOUNT_ID='Id/Ids' CLASS='Article'
  DESC

  partial_reindex_comment = <<-DESC
    - partial_reindex task aborted!!!
      * Minimum number of account ids to be specified = 1
      * If you want the task to be run for multiple accounts specify account ids seperated by a ','
        in the ACCOUNT_ID variable
        $ rake freshdesk_tire:partial_reindex ACCOUNT_ID='Id/Ids'
  DESC

  multi_class_import_comment = <<-DESC
    - Multi class import aborted!!!

      * Minimum number of account ids to be specified = 1
      * If you want the task to be run for multiple accounts specify account ids seperated by a ','
        in the ACCOUNT_ID variable
        $ rake freshdesk_tire:multi_class_import ACCOUNT_ID='Id/Ids' CLASS='Article'
  DESC

  create_alias_and_import_comment = <<-DESC
    - Create alias and import classes aborted!!!

      * Minimum number of account ids to be specified = 1
      * Minimum number of classes to be specified = 1
      * If you want the task to be run for multiple accounts specify account ids seperated by a ','
        in the ACCOUNT_ID variable
      * If you want the task to be run for multiple classes specify classes seperated by a ','
        in the CLASS variable
      * Set ADD=true if running import for new models only
        $ rake freshdesk_tire:create_alias_and_import ACCOUNT_ID='Id/Ids' CLASS='Class/Classes'
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

  task :multi_class_import => :environment do
    Sharding.select_shard_of(ENV['ACCOUNT_ID']) do
      account = Account.find_by_id(ENV['ACCOUNT_ID'])
      account.make_current
      account.es_enabled_account.update_attribute(:imported, false)
      Sharding.run_on_slave do
        klasses = ENV['CLASS'].split(';')
        klasses.each do |klass|
          Search::EsIndexDefinition.es_cluster(account.id)
          ENV['CLASS'] = klass
          index_alias = Search::EsIndexDefinition.searchable_aliases(Array(klass.partition('.').first.constantize), account.id).to_s
          ENV['INDEX'] = index_alias
          Rake::Task["tire:import"].execute("CLASS='#{ENV['CLASS']}' INDEX=#{ENV['INDEX']}")
        end
      end
      account.es_enabled_account.update_attribute(:imported, true)
      Account.reset_current_account
    end
  end

  task :class_import  => :environment do
    begin
      klasses = ENV['CLASS']
      es_account_ids = ENV['ACCOUNT_ID'].split(',')
      es_account_ids.each do |account_id|
        if ENV['CLASS'].blank?
          puts '='*100, ' '*20+'All class import with default condition will be performed!!!', '='*100, ""
        end
        ENV['CLASS'] = import_classes(account_id, klasses)
        ENV['ACCOUNT_ID'] = account_id.to_s
        Rake::Task["freshdesk_tire:multi_class_import"].execute("CLASS='#{ENV['CLASS']}' ACCOUNT_ID=#{ENV['ACCOUNT_ID']}")
      end
    rescue
      puts '='*100, ' '*45+'USAGE', '='*100, class_import_comment, ""
    end
  end

  task :partial_reindex => :environment do
    if ENV['ACCOUNT_ID'].blank?
      puts '='*100, ' '*45+'USAGE', '='*100, partial_reindex_comment, ""
      exit(1)
    end
    es_account_ids = ENV['ACCOUNT_ID'].split(',')
    init_partial_reindex(es_account_ids)
  end

  task :create_alias_and_import => :environment do
    begin
      klasses = ENV['CLASS']
      es_account_ids = ENV['ACCOUNT_ID'].split(',')
      raise "Invalid parameters" if (klasses.blank? or es_account_ids.blank?)
      new_models = (ENV['ADD'].to_s == 'true')
      
      es_account_ids.each do |account_id|
        begin
          Sharding.select_shard_of(account_id) do
            account = Account.find_by_id(account_id)
            next if account.nil?
            account.make_current
            ENV['CLASS'] = import_classes(account_id, klasses)
            ENV['ACCOUNT_ID'] = account_id.to_s
            Search::EsIndexDefinition.create_aliases(account_id.to_i, new_models)
            Rake::Task["freshdesk_tire:multi_class_import"].execute("CLASS='#{ENV['CLASS']}' ACCOUNT_ID=#{ENV['ACCOUNT_ID']}")
          end
        rescue
          next 
        ensure
          Account.reset_current_account
        end
      end
    rescue
      puts '='*100, ' '*45+'USAGE', '='*100, create_alias_and_import_comment, ""
    end
  end
end

def init_es_indexing(es_account_ids)
  klasses = ENV['CLASS']
  existing_accounts = Array.new
  es_account_ids.each do |account_id|
    Sharding.select_shard_of(account_id) do
    account = Account.find_by_id(account_id)
    next if account.nil?
    account.make_current
    if account.es_enabled_account.nil?
      Search::CreateAlias.perform({ :account_id => account.id, :sign_up => false })
      ENV['CLASS'] = import_classes(account_id, klasses)
      ENV['ACCOUNT_ID'] = account_id.to_s
      Rake::Task["freshdesk_tire:multi_class_import"].execute("CLASS='#{ENV['CLASS']}' ACCOUNT_ID=#{ENV['ACCOUNT_ID']}")
    else
      puts '='*100, ' '*10+"Index already exists for Account ID: #{account_id}. Please use partial_reindex task for Account ID: #{account_id}", '='*100, ""
      existing_accounts.push(account_id)
    end
    Account.reset_current_account
   end
  end
  puts '='*100, ' '*10+"Index already exists for following accounts: #{existing_accounts.inspect}. You can use partial_reindex task to index the same", '='*100, "" unless existing_accounts.blank?
end

def init_partial_reindex(es_account_ids)
  es_account_ids.each do |account_id|
    Sharding.select_shard_of(account_id) do
    account = Account.find_by_id(account_id)
    next if account.nil?
    account.make_current
    ENV['ACCOUNT_ID'] = account_id.to_s
    unless account.es_enabled_account.nil?
      if account.es_enabled_account.imported
        Search::RemoveFromIndex::AllDocuments.perform({ :account_id => account.id })
        account.es_enabled_account.delete
        ENV['CLASS'] = ''
        Rake::Task["freshdesk_tire:create_index"].execute("ACCOUNT_ID=#{ENV['ACCOUNT_ID']}")
      else
        puts '='*100, ' '*10+"Import already running for Account ID: #{account_id}. Cancelled partial_reindex for Account: #{account_id}", '='*100, ""
      end
    else
      Rake::Task["freshdesk_tire:create_index"].execute("ACCOUNT_ID=#{ENV['ACCOUNT_ID']}")
    end
    Account.reset_current_account
  end
  end
end

def import_classes(id, klasses)
  import_classes = klasses.blank? ? ['User', 'Helpdesk::Ticket', 'Solution::Article', 'Topic', 'Customer', 'Helpdesk::Note', 'Helpdesk::Tag', 'Freshfone::Caller','Admin::CannedResponses::Response'] : klasses.split(',')
  import_classes.collect!{ |item| "#{item}#{import_condition(id, item)}" }.join(';')
end

def import_condition(id, item)
  condition = ".scoped(:conditions => ['account_id=? and updated_at<?', #{id}, Time.now.utc])"
  case item.strip
    when "Helpdesk::Ticket" then
      condition = ".scoped(:conditions => ['account_id=? and updated_at<? and deleted=? and spam=?', #{id}, Time.now.utc, false, false])"
    when "User" then
      condition = ".scoped(:conditions => ['account_id=? and updated_at<? and deleted=?', #{id}, Time.now.utc, false])"
    when "Helpdesk::Note" then
      condition = ".scoped(:conditions => ['account_id=? and updated_at<? and notable_type=? and deleted=? and source<>?', #{id}, Time.now.utc, 'Helpdesk::Ticket', false, Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['meta']])"
    when "Helpdesk::Tag" then
      condition = ".scoped(:conditions => ['account_id=?', #{id}])"
    when "Freshfone::Caller" then
      condition = ".scoped(:conditions => ['account_id=?', #{id}])"
    when "Admin::CannedResponses::Response" then
      condition = ".scoped(:conditions => ['account_id=?', #{id}])"
  end
  condition
end
