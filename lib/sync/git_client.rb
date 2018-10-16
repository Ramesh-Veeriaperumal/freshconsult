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
      @repo_client   =  Rugged::Repository.new("#{repo_path}/.git") if File.directory?("#{repo_path}/.git")
    end

    def get_changes(target, source)
      run_git_command do
        run_and_log "git checkout #{source}"
        run_and_log "git checkout #{target}"
        run_and_log "git merge -s resolve origin/#{source} --no-commit --no-ff "
      end
      diff                      =  repo_client.head.target.tree.diff(repo_client.index)
      diff_changes              =  {}
      diff_changes[:modified]   =  diff.deltas.select { |d| d.status == :modified }.map { |d| { d.old_file[:path] => [d.old_file[:oid], d.new_file[:oid]] } }.inject(:merge)
      diff_changes[:deleted]    =  diff.deltas.select { |d| d.status == :deleted }.map { |d| { d.old_file[:path] => [d.old_file[:oid], d.new_file[:oid]] } }.inject(:merge)
      diff_changes[:added]      =  diff.deltas.select { |d| d.status == :added }.map { |d| { d.old_file[:path] => [d.old_file[:oid], d.new_file[:oid]] } }.inject(:merge)
      diff_changes[:conflict]   =  repo_client.index.conflicts.map { |d| { d[:ancestor].try(:[], :path) => [d[:ours].try(:[], :oid), d[:theirs].try(:[], :oid), d[:ancestor].try(:[], :oid)] } }.inject(:merge)
      diff_changes
    end

    def remove_repo(stale_branch, master)
      if repo_client.branches.to_a.collect(&:name).include?("origin/#{stale_branch}")
        Sync::Logger.log 'Branch found. Deleting the branch'
        run_git_command do
          run_and_log("git checkout #{master}")
          run_and_log("git push origin --delete #{stale_branch}")
          run_and_log("git branch -d #{stale_branch}")
        end
      else
        Sync::Logger.log 'Branch not found.'
      end
    end

    def create_branch(new_branch)
      run_git_command do
        run_and_log("git checkout -b #{new_branch}")
        run_and_log("git push -u origin #{new_branch}")
      end
    end

    def create_tag(tag, branch)
      run_git_command do
        run_and_log("git tag #{tag} #{branch}")
        run_and_log("git push origin #{tag}")
      end
    end

    def fetch_origin
      run_git_command do
        run_and_log('git fetch origin')
      end
    end

    def merge_branches(target, source, message, author, email)
      # checkout the source branch

      run_git_command do
        run_and_log "git checkout -b #{source} origin/#{source}"
        run_and_log "git checkout #{target}"
      end

      conflicts = merge_conflicts(target, source)

      if conflicts.blank?
        run_git_command do
          run_and_log "git checkout #{target}"
          run_and_log "git merge --squash origin/#{source}"
          run_and_log "git commit -m \"#{message}\" --author \"#{author} <#{email}>\""
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
        run_and_log("git push origin #{@branch}")
      end
    end

    def commit_all_changed_files(message, author, email)
      run_git_command do
        run_and_log('git add -A .')
        run_and_log("git commit -m \"#{message}\" --author \"#{author} <#{email}>\" ")
      end
    end

    # XXX - Todo -- Not working for deleted files
    # def commit_all_changed_files(message, author, email)
    #   files = []
    #   repo_client.status { |file, status_data| files << file}

    #   index = repo_client.index
    #   files.each do |file|
    #     oid   = Rugged::Blob.from_workdir(repo_client, file)
    #     index.add(:path => file, :oid => oid, :mode => 0100644)
    #   end

    #   options = {}
    #   options[:tree] = index.write_tree(repo_client)

    #   options[:author] = {
    #     :email  => email,
    #     :name   => author,
    #     :time   => Time.now
    #   }
    #   options[:committer] = {
    #     :email  => email,
    #     :name   => author,
    #     :time   => Time.now
    #   }
    #   options[:message]     =  message
    #   options[:parents]     =  repo_client.empty? ? [] : [ repo_client.head.target ].compact
    #   options[:update_ref]  =  'HEAD'

    #   commit = Rugged::Commit.create(repo_client, options)
    #   index.write()
    # end

    def checkout_branch
      # @repo_client ||= Rugged::Repository.clone_at(@repo_url, @repo_path, {
      #   transfer_progress: lambda { |total_objects, indexed_objects, received_objects, local_objects, total_deltas, indexed_deltas, received_bytes|
      #     print "."
      #   },
      #   credentials: credentials,
      #   checkout_branch: @branch
      # })
      clone_repo
      fetch_and_switch
    end

    def fetch_and_switch
      branch = repo_client.branches["origin/#{@branch}"]

      # Create the branch
      if branch.nil?
        run_git_command do
          run_and_log 'git checkout master'
          run_and_log "git checkout -b #{@branch}"
          run_and_log "git push origin -u #{@branch}"
        end
      else
        run_git_command do
          run_and_log "git checkout origin/#{@branch}"
          run_and_log "git checkout -b #{@branch}"
        end
      end
    end

    def clone_repo
      @repo_client ||= Rugged::Repository.clone_at(@repo_url, @repo_path,
                                                   transfer_progress: lambda { |total_objects, indexed_objects, received_objects, local_objects, total_deltas, indexed_deltas, received_bytes|
                                                     print '.'
                                                   },
                                                   credentials: credentials)
    end

    def credentials
      Rugged::Credentials::SshKey.new(privatekey: @private_key, publickey: @public_key, passphrase: '', username: @username)
    end

    def run_git_command
      Dir.chdir @repo_path
      yield
      Dir.chdir Rails.root
    end

    def run_and_log(command, log = true)
      Sync::Logger.log command
      Sync::Logger.log system(command)
    end

    class ConfigConflictError < StandardError
    end
  end
end
