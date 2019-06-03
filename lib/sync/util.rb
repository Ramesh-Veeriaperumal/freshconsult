module Sync::Util
  include Sync::Constants

  # XXX TODO - remove all Sync:: since they r under the same namespace

  def sync_config_to_local(account_id, repo_path)
    FileUtils.rm_rf(repo_path)
    branch    = branch_name(account_id)
    gitClient = Sync::GitClient.new(repo_path, branch)
    gitClient.checkout_branch
  end

  def generate_config(repo_path, master_account_id = nil, sandbox = false)
    all_relations = RELATIONS
    all_relations += CLONE_RELATIONS if @clone
    all_relations.each do |relation|
      Sync::DataToFile::Manager.new(repo_path, master_account_id, relation[0], relation[1], sandbox).write_config
    end
  end

  def commit_and_push_config_to_git(account_id, repo_path, message, author, email)
    branch    = branch_name(account_id)
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

  def restore_config_from_git(master_account_id, staging_account_id, repo_path, retain_id)
    account = Account.find(staging_account_id).make_current
    s = Sync::FileToData::Manager.new(repo_path, master_account_id, retain_id, false, @clone)
    clear_staging_data(s.affected_tables, account.id)
    s.update_all_config
    s.post_config
  ensure
    Account.reset_current_account
  end

  def get_diff(master_account_id, staging_account_id, repo_path)
    master_branch  = branch_name(master_account_id)
    staging_branch = branch_name(staging_account_id)

    git_client = Sync::GitClient.new(repo_path, master_branch)
    git_client.get_changes(master_branch, staging_branch)
  end

  def apply_staging_config_to_prod(account_id, staging_account_id, repo_path, resync, retain_id, merge_changes)
    Sharding.select_shard_of(account_id) do
      Account.find(account_id).make_current
      @repo_client = Rugged::Repository.new("#{repo_path}/.git")
      @file_to_data = Sync::FileToData::Manager.new("#{RESYNC_ROOT_PATH}/#{account_id}", staging_account_id, retain_id, resync)
      MERGE_FILES_TYPES.each do |type|
        next unless merge_changes[type]
        files_config(repo_path, account_id, merge_changes[type], type)
      end
      # Post config
      @file_to_data.post_config
    end
  ensure
    Account.reset_current_account
  end

  def files_config(repo_path, account_id, files, action)
    create_config_files(files, repo_path, account_id)
    @file_to_data.update_all_config(action)
  end

  def create_file(path, content)
    FileUtils.mkdir_p(File.dirname(path))
    File.open(path, 'w') { |f| f.puts content }
  end

  def traverse_directory(dir_path)
    Dir.foreach(dir_path) do |item|
      next if (item == '.') || (item == '..')
      yield(item)
    end
  end

  def load_mapping_table(path)
    YAML.load(File.read("#{path}/#{MAPPING_TABLE_NAME}.txt"))
  end

  private

    def create_config_files(files, repo_path, account_id)
      FileUtils.rm_rf(RESYNC_ROOT_PATH + '/' + account_id.to_s)
      files.each do|file, content|
        next unless file
        file_path =  repo_path + '/' + file
        new_file = file_path.gsub(GIT_ROOT_PATH, RESYNC_ROOT_PATH)
        FileUtils.mkdir_p(File.dirname(new_file))
        # copy file
        if File.exist?(file_path)
          FileUtils.cp(file_path, File.dirname(new_file))
        else
          create_file(new_file, load_content_from_hash(content[0]))
        end
      end
    end

    def load_content_from_hash(hash_id)
      return unless hash_id
      @repo_client.lookup(hash_id).content
    end

    def branch_name(account_id)
      @branch.present? ? @branch.to_s : account_id.to_s
    end
end
