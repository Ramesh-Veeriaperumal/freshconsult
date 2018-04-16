if Rails.env.development?
<<<<<<< HEAD
  module GitHooksInit
    def self.link_script(script_name)
      `rm "#{Rails.root}/.git/hooks/#{script_name}"`
      `ln -s "#{Rails.root}/script/githooks/#{script_name}" "#{Rails.root}/.git/hooks/#{script_name}"`
      `chmod +x "#{Rails.root}/.git/hooks/#{script_name}"`
=======
  # Sets up git hooks when starting up rails server or console
  module GitHooksInit
    def self.link_script(script_name)
      rails_root = Rails.root
      `rm "#{rails_root}/.git/hooks/#{script_name}"`
      `ln -s "#{rails_root}/script/githooks/#{script_name}" "#{rails_root}/.git/hooks/#{script_name}"`
      `chmod +x "#{rails_root}/.git/hooks/#{script_name}"`
>>>>>>> origin/staging
    end

    def self.add_scripts
      link_script 'pre-commit'
      link_script 'prepare-commit-msg'
      link_script 'commit-msg'
    end
  end

  GitHooksInit.add_scripts
end
