# Re-definitions are appended to existing tasks
task :environment
task :merb_env

namespace :jobs do
  desc "Clear the delayed_job queue."
  task :clear => [:merb_env, :environment] do
    Delayed::Job.delete_all
  end

  desc "Start a delayed_job worker."
  task :work => [:merb_env, :environment] do
    Delayed::Worker.new(::Delayed::Job, :min_priority => ENV['MIN_PRIORITY'], :max_priority => ENV['MAX_PRIORITY']).start
  end
end


namespace :mailbox_jobs do
  desc "Clear the mailbox_job queue."
  task :clear => :environment do
    Mailbox::Job.delete_all
  end

  desc "Start a delayed_job worker."
  task :work => :environment do
    Delayed::Worker.new(::Mailbox::Job, :min_priority => ENV['MIN_PRIORITY'], :max_priority => ENV['MAX_PRIORITY']).start
  end
end
