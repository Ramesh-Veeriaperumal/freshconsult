module Sync
  class GitClient
    attr_accessor :repo_client, :repo_url

    def initialize(repo_path, branch = nil)
      @repo_url      =  SANDBOX_REPO_URL
      @private_key   =  SANDBOX_PRIVATE_KEY
      @public_key    =  SANDBOX_PUBLIC_KEY
      @username      =  SANDBOX_USERNAME
      @repo_path     =  repo_path
      @branch        =  branch
      @repo_client   =  Rugged::Repository.new("#{repo_path}/.git") if repo_path_exists?
    end

    def get_changes(target, source)
      run_git_command do
        add_and_fetch_branch(source)
        execute_command "git checkout #{source}"
        execute_command "git checkout #{target}"
        execute_command "git merge -s resolve origin/#{source} --no-commit --no-ff"
      end
      diff                      =  repo_client.head.target.tree.diff(repo_client.index)
      diff_changes              =  {}
      diff_changes[:modified]   =  diff.deltas.select { |d| d.status == :modified }.map { |d| { d.old_file[:path] => [d.old_file[:oid], d.new_file[:oid]] } }.inject(:merge)
      diff_changes[:deleted]    =  diff.deltas.select { |d| d.status == :deleted }.map { |d| { d.old_file[:path] => [d.old_file[:oid], d.new_file[:oid]] } }.inject(:merge)
      diff_changes[:added]      =  diff.deltas.select { |d| d.status == :added }.map { |d| { d.old_file[:path] => [d.old_file[:oid], d.new_file[:oid]] } }.inject(:merge)
      diff_changes[:conflict]   =  repo_client.index.conflicts.map { |d| { d[:ancestor].try(:[], :path) => [d[:ours].try(:[], :oid), d[:theirs].try(:[], :oid), d[:ancestor].try(:[], :oid)] } }.inject(:merge)
      diff_changes
    end

    def remove_branch(stale_branch, master)
      if repo_client.branches.to_a.collect(&:name).include?("origin/#{stale_branch}")
        Sync::Logger.log 'Branch found. Deleting the branch'
        run_git_command do
          execute_command("git checkout #{master}")
          execute_command("git push origin --delete #{stale_branch}")
          execute_command("git branch -d #{stale_branch}")
        end
      else
        Sync::Logger.log 'Branch not found.'
      end
    end

    def remove_remote_branch(branch_name)
      if branch_exists?(branch_name, true)
        Sync::Logger.log "Remote Branch found. Deleting branch: #{branch_name}"
        execute_command("git push #{repo_url} --delete #{branch_name}")
      else
        Sync::Logger.log "Remote Branch not found: #{branch_name}"
      end
    end

    def create_branch(new_branch)
      run_git_command do
        execute_command("git checkout -b #{new_branch}")
        execute_command("git push -u origin #{new_branch}")
      end
    end

    def create_tag(tag, branch)
      run_git_command do
        execute_command("git tag #{tag} #{branch}")
        execute_command("git push origin #{tag}")
      end
    end

    def fetch_origin
      run_git_command do
        execute_command('git fetch origin')
      end
    end

    def merge_branches(target, source, message, author, email)
      # checkout the source branch

      run_git_command do
        execute_command "git checkout -b #{source} origin/#{source}"
        execute_command "git checkout #{target}"
      end

      conflicts = merge_conflicts(target, source)

      if conflicts.blank?
        run_git_command do
          execute_command "git checkout #{target}"
          execute_command "git merge --squash origin/#{source}"
          execute_command "git commit -m \"#{message}\" --author \"#{author} <#{email}>\""
        end
        [true, conflicts]
      else
        [false, conflicts]
      end
    end

    def merge_conflicts(target, source)
      conflict_files = []
      our_commit     = repo_client.branches[target].target
      their_commit   = repo_client.branches[source].target

      merge_index = repo_client.merge_commits(
        our_commit,
        their_commit
      )

      if merge_index.conflicts?
        conflict_files = merge_index.conflicts.map { |x| x[:ours][:path] if x[:ours] }
      end

      conflict_files
      # merge_commit = Rugged::Commit.create(repo_client, {
      #   parents: [
      #     our_commit,
      #     their_commit
      #   ],
      #   tree: merge_index.write_tree(repo_client),
      #   message: message,
      #   author:    { name: author, email: email },
      #   committer: { name: author, email: email },
      #   update_ref: repo_client.branches[target].canonical_name
      # })
    end

    def push_changes_to_remote
      run_git_command do
        execute_command("git push origin #{@branch}")
      end
    end

    def commit_all_changed_files(message, author, email)
      run_git_command do
        execute_command('git add -A .')
        execute_command("git commit -m \"#{message}\" --author \"#{author} <#{email}>\" ", true)
      end
    end

    def checkout_branch
      Rails.logger.info 'Starting single branch git clone...'
      FileUtils.remove_dir(@repo_path) if repo_path_exists?
      branch_name = branch_exists?(@branch) ? @branch : 'master'
      execute_command("git clone #{repo_url} --branch #{branch_name} --single-branch #{@repo_path}")
      @repo_client ||= Rugged::Repository.new("#{@repo_path}/.git") if repo_path_exists?
      Rails.logger.info 'Single branch git clone completed...'

      # Create branch if not present and switch
      branch = repo_client.branches["origin/#{@branch}"]
      create_branch(@branch.to_s) if branch.nil?
    end

    def branch_exists?(branch_name, use_repo_url = false)
      remote = !use_repo_url && repo_path_exists? ? 'origin' : @repo_url
      command = "git ls-remote --heads #{remote} #{branch_name}"
      execute_command(command, true).present?
    end

    def add_and_fetch_branch(branch_name)
      return false unless branch_exists?(branch_name)

      execute_command("git remote set-branches --add origin #{branch_name}")
      execute_command("git fetch origin #{branch_name}:#{branch_name}")
    end

    def run_git_command
      Dir.chdir @repo_path
      yield
      Dir.chdir Rails.root
    end

    def execute_command(command, log_and_return_full_output = false)
      Sync::Logger.log(command)
      # `` returns console output (entire result)
      # system() returns true/false corresponding success/failure of command
      output = log_and_return_full_output ? `#{command}` : system(command)
      Sync::Logger.log(output)
      output
    end

    def repo_path_exists?
      File.directory?("#{@repo_path}/.git")
    end

    class ConfigConflictError < StandardError
    end
  end
end
