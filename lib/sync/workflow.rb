module Sync
  class Workflow
    include Util

    attr_accessor :master_account_id, :repo_path, :staging_account_id, :retain_id, :staging_repo_path

    def initialize(staging_account_id = nil, retain_id = true, master_account_id = Account.current.id, clone = false, branch = nil)
      @master_account_id  = master_account_id
      @staging_account_id = staging_account_id
      @retain_id          = retain_id
      @repo_path          = "#{GIT_ROOT_PATH}/#{master_account_id}"
      @staging_repo_path  = "#{GIT_ROOT_PATH}/#{staging_account_id}"
      @clone              = clone
      @branch             = branch
    end

    def sync_config_from_production(committer)
      sync_config_to_local(@master_account_id, repo_path)
      commit_config_to_git(repo_path, master_account_id)
      message = "Storing Config #{Time.now.strftime('%H:%M:%S')}"
      sync_config_to_remote(@master_account_id, repo_path, message, committer[:name], committer[:email])
    end

    def provision_staging_instance(committer)
      shard = ShardMapping.find_by_account_id(staging_account_id).shard_name
      Sharding.run_on_shard(shard) do
        create_staging_branch
        restore_config_from_git(master_account_id, staging_account_id, repo_path, retain_id)
        message = "Storing mapping table #{Time.now.strftime('%H:%M:%S')}"
        sync_config_to_remote(staging_account_id, repo_path, message, committer[:name], committer[:email])
      end
    end

    def sync_config_from_sandbox(committer)
      sync_config_to_local(staging_account_id, staging_repo_path)
      Sharding.admin_select_shard_of(staging_account_id) do
        @account = Account.find(staging_account_id).make_current
        commit_config_to_git(staging_repo_path, master_account_id, true)
      end
      message = "Storing Config #{Time.now.strftime('%H:%M:%S')}"
      sync_config_to_remote(@staging_account_id, staging_repo_path, message, committer[:name], committer[:email])
    end

    def move_sandbox_config_to_prod(committer)
      sync_config_to_local(master_account_id, repo_path)
      merge_changes = get_diff(master_account_id, staging_account_id, repo_path)
      if merge_changes[:conflict].blank?
        apply_staging_config_to_prod(master_account_id, staging_account_id, repo_path, true, retain_id, merge_changes)
        message = "Merge from sandbox config #{Time.now.strftime('%H:%M:%S')}"
        sync_config_to_remote(master_account_id, repo_path, message, committer[:name], committer[:email])
      else
        raise 'conflicts found in move_sandbox_config_to_prod'
      end
    end

    def sandbox_config_changes
      sync_config_to_local(master_account_id, repo_path)
      get_diff(master_account_id, staging_account_id, repo_path)
    end

    private

      def create_staging_branch
        master_branch  = branch_name(@master_account_id)
        staging_branch = branch_name(@staging_account_id)

        FileUtils.rm_rf(repo_path)
        gitClient = GitClient.new(repo_path, master_branch)
        gitClient.checkout_branch
        gitClient.remove_repo(staging_branch, master_branch) # Start from scratch. Delete the old staging branch
        gitClient.create_tag("#{master_branch}-#{Time.now.strftime('%Y-%m-%d-%H-%M-%S')}", master_branch) # create a tag for reference
        gitClient.create_branch(staging_branch) # create new branch from master
      end
  end
end
