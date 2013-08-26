FAILED_DELAYED_JOBS_THRESHOLD = Rails.env.production? ? 100 : 2
TOTAL_DELAYED_JOBS_THRESHOULD = Rails.env.production? ? 500 : 50


FAILED_RESQUE_JOBS_THRESHOLD = 500
QUEUE_WATCHER_RULE = {
    :threshold => {
        "observer_worker" => 5000,
        "update_ticket_states_queue" => 5000,
        "premium_supervisor_worker" => 5000,
        "es_index_queue" => 10000,
        "sla_worker" => 15000
    } ,
    :except => ["supervisor_worker"]
}

namespace :delayedjobs_watcher do 
    desc 'To keep a tab on failed delayed jobs '
    task :failed_jobs => :environment do
        failed_jobs_count =  Delayed::Job.count(:conditions => ["last_error is not null and attempts > 1"])
        FreshdeskErrorsMailer.deliver_error_email(nil, nil, nil,{  
            :subject => "Delayed jobs needs your attention #{failed_jobs_count} failed jobs" 
        }) if failed_jobs_count >= FAILED_DELAYED_JOBS_THRESHOLD
    end

    desc "Monitoring growing queue of delayed jobs"
    task :total_jobs => :environment do
        total_jobs_count = Delayed::Job.count
        FreshdeskErrorsMailer.deliver_error_email(nil, nil, nil,{  
            :subject => "Delayed jobs needs your attention #{total_jobs_count} jobs are in queue" 
        }) if total_jobs_count >= TOTAL_DELAYED_JOBS_THRESHOULD
        
    end
end

namespace :resque_watcher do 
    desc 'To keep a tab on resque failed jobs'
    task :failed_jobs => :environment do
        failed_jobs_count = Resque::Failure.count
        FreshdeskErrorsMailer.deliver_error_email(nil, nil, nil,
            {  :subject => "Resque needs your attention #{failed_jobs_count} failed jobs" }
        ) if failed_jobs_count >= FAILED_RESQUE_JOBS_THRESHOLD
    end

    desc "Monitoring growing queue of resque"
    task :check_load => :environment do

        queues = Resque.queues & 
        (QUEUE_WATCHER_RULE[:only] || Resque.queues) - 
        (QUEUE_WATCHER_RULE[:except] || [])

        queue_info = Hash[*queues.map do |queue_name| 
            queue_size = Resque.size(queue_name)
            queue_size > get_threshold(queue_name) ? [queue_name, queue_size] : []
        end.flatten]
        details_hash = {
          :subject          => "Resque is queuing up. Needs your attention!",
          :additional_info => queue_info
        }
        
        FreshdeskErrorsMailer.deliver_error_email(nil, nil, nil,details_hash) unless queue_info.empty?
    end

    def get_threshold(queue_name)
        return 10 unless Rails.env.production?
        QUEUE_WATCHER_RULE[:threshold][queue_name] || 15000
    end
end


