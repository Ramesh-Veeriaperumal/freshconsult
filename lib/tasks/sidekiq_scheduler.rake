require 'sidekiq'
require 'sidekiq/util'
require 'sidekiq/actor'
require 'sidekiq/api'
require 'celluloid'
require 'sidekiq/scheduled'


namespace :sidekiq_scheduler do
  desc "This task triggeres scheduler every 30 seconds" 
  task :enqueue_sidekiq_jobs => :environment do
    loop do 
      puts "Looping ....."
      enq = Sidekiq::Scheduled::Enq.new
      begin
      enq.enqueue_jobs(Time.now.to_f.to_s, ["schedule"])
      rescue => ex
      # Most likely a problem with redis networking.
      # Punt and try again at the next interval
      puts ex.message
      puts ex.backtrace.first
      end
      sleep 30
    end  
  end
end
