if Rails.env.development?
  # Sets up git hooks when starting up rails server or console
  module GitHooksInit
    def self.link_script(script_name)
      rails_root = Rails.root
      `rm "#{rails_root}/.git/hooks/#{script_name}"`
      `ln -s "#{rails_root}/script/githooks/#{script_name}" "#{rails_root}/.git/hooks/#{script_name}"`
      `chmod +x "#{rails_root}/.git/hooks/#{script_name}"`
    end

    def self.add_scripts
      link_script 'pre-commit'
      link_script 'prepare-commit-msg'
      link_script 'commit-msg'
    end
  end

  GitHooksInit.add_scripts
end
