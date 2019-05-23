module Sync::Util

  include Sync::Constants

  #XXX TODO - remove all Sync:: since they r under the same namespace

  def sync_config_to_local(account_id, repo_path)
    FileUtils.rm_rf(repo_path)

    branch    = branch_name(account_id)
    gitClient = Sync::GitClient.new(repo_path, branch)
    gitClient.checkout_branch
  end

  def commit_config_to_git(account_id, repo_path, configs)
    RELATIONS.each do |relation|
      next unless configs.include?(relation[0])
      Sync::ConfigToFile.new(repo_path, relation[0], relation[1]).write_config
    end
  end

  def sync_config_to_remote(account_id, repo_path, message, author, email)
    branch = branch_name(account_id)
    gitClient = Sync::GitClient.new(repo_path, branch)
    gitClient.commit_all_changed_files(message, author, email)
    gitClient.push_changes_to_remote
  end

  def clear_staging_data(tables, account_id)
    puts "Clearing Staging Data : #{tables.inspect}"
    tables.each do |table|
      sql = "DELETE from #{table} where account_id = #{account_id}"
      puts "******** Deleting data with query #{sql}" 
      ActiveRecord::Base.connection.execute(sql)
    end
  end

  def restore_config_from_git(master_account_id, staging_account_id, repo_path)
    account = Account.find(staging_account_id).make_current
    s = Sync::FileToConfig.new(repo_path, master_account_id, account)
    clear_staging_data(s.affected_tables, account.id)
    s.update_all_config
  ensure
    Account.reset_current_account
  end

  def merge_branches(master_account_id, staging_account_id, repo_path, message, author, email)
    master_branch  = branch_name(master_account_id)
    staging_branch = branch_name(staging_account_id)

    gitClient = Sync::GitClient.new(repo_path, master_branch)
    success, conflicts = gitClient.merge_branches(master_branch, staging_branch, message, author, email)
    if success
      gitClient.push_changes_to_remote
    else
      puts "Merge Failed. Please check the conflicting files"
    end
    [success, conflicts]
  end

  #TODO : Handling Reverse Mapping. eg., Ticket fields. What if ticket field column is already been taken
  def apply_staging_config_to_prod(account_id, repo_path, new_files, modified_files, deleted_files)
    Sharding.select_shard_of(account_id) do
      account = Account.find(account_id).make_current
      RELATIONS.each do |relation|
        Sync::FileToConfig.new(repo_path, relation[0], account).update_config(modified_files)
        Sync::FileToConfig.new(repo_path, relation[0], account).delete_config(deleted_files)
      end
    end
  ensure
    Account.reset_current_account
  end

  def backup_single_object(account_id, repo_path, association, object)
    Sharding.select_shard_of(account_id) do
      account = Account.find(account_id).make_current
      Sync::ConfigToFile.new(repo_path, association, [], account).dump_object(repo_path, association, object)
    end
  ensure
    Account.reset_current_account
  end

  private 
  
  # def table_directory_hash(account_id, repo_path)
  #   tables = {}
  #   tdir = {}
  #     account = Account.find(account_id).make_current
  #     RELATIONS.each do |relation|
  #       ftoc = Sync::FileToConfig.new("teting", relation[0], account)
  #       tdir[relations[0]]  = ftoc.table_directories
  #     end
  #     p "#{tdir.inspect}"
  # end

  def branch_name(account_id)
    "#{BRANCH_PREFIX}#{account_id}"
  end
end
