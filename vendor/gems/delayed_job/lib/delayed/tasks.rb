namespace :jobs do
  desc "Clear the delayed_job queue."
  task :clear => :environment do
    Delayed::Job.delete_all
  end

  desc "Start a delayed_job worker."
  task :work => :environment do
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

namespace :free_account_jobs do
  desc "Clear the free_account_job queue."
  task :clear => :environment do
    Free::Job.delete_all
  end

  desc "Start a delayed_job worker."
  task :work => :environment do
    Delayed::Worker.new(::Free::Job, :min_priority => ENV['MIN_PRIORITY'], :max_priority => ENV['MAX_PRIORITY']).start
  end
end

namespace :active_account_jobs do
  desc "Clear the active_account_job queue."
  task :clear => :environment do
    Active::Job.delete_all
  end

  desc "Start a delayed_job worker."
  task :work => :environment do
    Delayed::Worker.new(::Active::Job, :min_priority => ENV['MIN_PRIORITY'], :max_priority => ENV['MAX_PRIORITY']).start
  end
end

namespace :premium_account_jobs do
  desc "Clear the premium_account_job queue."
  task :clear => :environment do
    Premium::Job.delete_all
  end

  desc "Start a delayed_job worker."
  task :work => :environment do
    Delayed::Worker.new(::Premium::Job, :min_priority => ENV['MIN_PRIORITY'], :max_priority => ENV['MAX_PRIORITY']).start
  end
end


namespace :trial_account_jobs do
  desc "Clear the trial_account_job queue."
  task :clear => :environment do
    Trial::Job.delete_all
  end

  desc "Start a delayed_job worker."
  task :work => :environment do
    Delayed::Worker.new(::Trial::Job, :min_priority => ENV['MIN_PRIORITY'], :max_priority => ENV['MAX_PRIORITY']).start
  end
end




