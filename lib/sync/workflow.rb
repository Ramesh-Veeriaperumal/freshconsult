module Sync    
  class Workflow  

    include Util

    attr_accessor :master_account_id, :repo_path, :staging_account_id    

    def initialize(staging_account_id=nil, master_account_id=Account.current.id)
      @master_account_id  = master_account_id
      @staging_account_id = staging_account_id
      @repo_path          = "#{GIT_ROOT_PATH}/#{master_account_id}"
    end
    
    def sync_config_from_production(committer, message, configs)
      FileUtils.rm_rf(repo_path)
      sync_config_to_local(@master_account_id, repo_path)
      commit_config_to_git(@master_account_id, repo_path, configs)
      sync_config_to_remote(@master_account_id, repo_path, message, committer[:name], committer[:email])
    end

    def provision_staging_instance
      shard = ShardMapping.find_by_account_id(staging_account_id).shard_name
      Sharding.run_on_shard(shard) do
        create_staging_branch
        restore_config_from_git(master_account_id, staging_account_id, repo_path)
      end
    end

    def move_staging_config_to_prod(committer, message)
      sync_config_to_local(@master_account_id, repo_path)
      merge_branches(@master_account_id, @staging_account_id, repo_path, message, committer[:name], committer[:email])
      #update_prod_config(repo_path)
    end

    def update_prod_config
      gitClient  = GitClient.new(repo_path)
      new_files, modified_files, deleted_files = gitClient.merge_commit_changes
      apply_staging_config_to_prod(@master_account_id, repo_path, new_files, modified_files, deleted_files)      
    end    
    
    private

    def create_staging_branch
      master_branch  = branch_name(@master_account_id)
      staging_branch = branch_name(@staging_account_id)

      FileUtils.rm_rf(repo_path)

      gitClient  = GitClient.new(repo_path, master_branch)
      gitClient.checkout_branch
      gitClient.remove_repo(staging_branch, master_branch)  #Start from scratch. Delete the old staging branch
      gitClient.create_tag("#{master_branch}-#{Time.now.strftime("%Y-%m-%d-%H-%M-%S")}", master_branch) # create a tag for reference
      gitClient.create_branch(staging_branch) #create new branch from master
    end
  end
end
