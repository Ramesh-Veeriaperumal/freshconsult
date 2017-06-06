if Rails.env.development?
  module GitHooksInit
    def self.link_script(script_name)
      `rm "#{Rails.root}/.git/hooks/#{script_name}"`
      `ln -s "#{Rails.root}/script/githooks/#{script_name}" "#{Rails.root}/.git/hooks/#{script_name}"`
      `chmod +x "#{Rails.root}/.git/hooks/#{script_name}"`
    end

    def self.add_scripts
      link_script 'pre-commit'
      link_script 'prepare-commit-msg'
      link_script 'commit-msg'
    end
  end

  GitHooksInit.add_scripts
end
