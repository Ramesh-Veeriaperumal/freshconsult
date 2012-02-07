require "eycap/recipes"

# =================================================================================================
# ENGINE YARD REQUIRED VARIABLES
# =================================================================================================
# You must always specify the application and repository for every recipe. The repository must be
# the URL of the repository you want this recipe to correspond to. The :deploy_to variable must be
# the root of the application.

set :keep_releases,       5
set :application,         "helpkit"
set :user,                "freshdesk"
set :password,            "33l4npP3DPx451w"
set :deploy_to,           "/data/#{application}"
set :monit_group,         "helpkit"
set :runner,              "freshdesk"
set :repository,          "git@github.com:freshdesk/helpkit.git"
set :branch,              "ey_managed_freshdesk" # remove this when you want to deploy from master
set :scm,                 :git
set :deploy_via,          :remote_cache
set :production_database, "helpkit_production"
set :production_dbhost,   "freshdesk-mysql-production-master"
set :staging_database,    "helpkit_staging"
set :staging_dbhost,      "freshdesk-mysql-staging-master"
set :dbuser,              "freshdesk_db"
set :dbpass,              "nlhlqo5tfeIh3su"

# comment out if it gives you trouble. newest net/ssh needs this set.
ssh_options[:paranoid] = false

# =================================================================================================
# ROLES
# =================================================================================================
# You can define any number of roles, each of which contains any number of machines. Roles might
# include such things as :web, or :app, or :db, defining what the purpose of each machine is. You
# can also specify options that can be used to single out a specific subset of boxes in a
# particular role, like :primary => true.

task :production do
  role :web, "209.251.187.86:7000" # helpkit [mongrel,sphinx,memcached] [freshdesk-mysql-production-master]
  role :app, "209.251.187.86:7000", :unicorn => true, :sphinx => true, :memcached => true
  role :db , "209.251.187.86:7000", :primary => true
  role :app, "209.251.187.86:7001", :unicorn => true, :dj => true, :memcached => true
  set :rails_env, "production"
  set :environment_database, defer { production_database }
  set :environment_dbhost, defer { production_dbhost }
end

task :staging do
  role :web, "209.251.187.87:7000" # helpkit [mongrel,sphinx,memcached] [freshdesk-mysql-staging-master]
  role :app, "209.251.187.87:7000", :unicorn => true, :sphinx => true, :memcached => true, :dj => true
  role :db , "209.251.187.87:7000", :primary => true
  set :rails_env, "staging"
  set :environment_database, defer { staging_database }
  set :environment_dbhost, defer { staging_dbhost }
end

# =================================================================================================
# desc "Example custom task"
# task :helpkit_custom, :roles => :app, :except => {:no_release => true, :no_symlink => true} do
#   run <<-CMD
#     echo "This is an example"
#   CMD
# end
# 
# after "deploy:symlink_configs", "helpkit_custom"
# =================================================================================================

# Task to restart unicorn afer deploy
namespace :deploy do
  task :restart, :roles => :app do
    unicorn.deploy
  end
end

namespace :dj do
  task :restart, :roles => [:app], :only => {:dj => true} do
    sudo "/usr/bin/monit restart all -g dj_#{monit_group}" # use dj_helpkit
  end
end

namespace :thinking_sphinx do
  desc "After update_code you want to configure, then reindex"
  task :configure, :roles => [:app], :only => {:sphinx => true}, :except => {:no_release => true} do
    run "/engineyard/bin/thinking_sphinx_searchd #{application} configure #{rails_env}"
  end

  desc "After configure you want to reindex"
  task :reindex, :roles => [:app], :only => {:sphinx => true} do
    run "/engineyard/bin/thinking_sphinx_searchd #{application} reindex #{rails_env}"
  end
end

after "deploy", "deploy:cleanup"
after "deploy:migrations" , "deploy:cleanup"
after "deploy:update_code", "deploy:symlink_configs"

after "deploy:cleanup", "dj:restart"
after "deploy:symlink_configs", "thinking_sphinx:symlink"

after "deploy:symlink", "thinking_sphinx:configure"
after "thinking_sphinx:configure", "thinking_sphinx:reindex"
