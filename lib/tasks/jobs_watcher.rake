FAILED_DELAYED_JOBS_THRESHOLD = Rails.env.production? ? 100 : 2
TOTAL_DELAYED_JOBS_THRESHOULD = Rails.env.production? ? 500 : 50
#pagerduty constants 
TOTAL_DJ_PAGERDUTY_THRESHOULD = Rails.env.production? ? 5000 : 50
FAILED_DJ_PAGERDUTY_THRESHOLD = Rails.env.production? ? 200 : 2
PAGER_DUTY_FREQUENCY_SECS = Rails.env.production? ? 18000 : 900 #5 hours : # 15 mins

PAGERDUTY_QUEUES = [
    "observer_worker","update_ticket_states_queue"
]
DELAYED_JOBS_MSG = "Delayed jobs needs your attention!"
CUSTOM_MAILBOX_JOBS_MSG = "Custom Mailbox's delayed jobs needs your attention!"



FAILED_RESQUE_JOBS_THRESHOLD = 500
QUEUE_WATCHER_RULE = {
    :threshold => {
        "observer_worker" => 5000,
        "update_ticket_states_queue" => 5000,
        "premium_supervisor_worker" => 5000,
        "es_index_queue" => 10000,
        "sla_worker" => 25000,
        "free_sla_worker" => 25000,
        "trail_sla_worker" => 25000
    } ,
    :except => ["supervisor_worker"]
}


namespace :delayedjobs_watcher do 
    desc 'To keep a tab on failed delayed jobs '
    task :failed_jobs => :environment do

        failed_jobs_count =  Delayed::Job.count( 
            :conditions => ["last_error is not null and attempts > 1"]
        )

        FreshdeskErrorsMailer.deliver_error_email(nil, nil, nil,{  
            :subject => "#{DELAYED_JOBS_MSG} #{failed_jobs_count} failed jobs" 
        }) if failed_jobs_count >= FAILED_DELAYED_JOBS_THRESHOLD


        failed_custom_mailbox_jobs = Mailbox::Job.count(
            :conditions => ["last_error is not null and attempts > 1"]
        )
        FreshdeskErrorsMailer.deliver_error_email(nil, nil, nil, {
            :subject => "#{CUSTOM_MAILBOX_JOBS_MSG} #{failed_custom_mailbox_jobs} failed jobs" 
        }) if failed_custom_mailbox_jobs >= FAILED_DELAYED_JOBS_THRESHOLD

        #For every 5 hours we will init the alert
        if FAILED_DJ_PAGERDUTY_THRESHOLD <= failed_jobs_count and 
            $redis_others.get("FAILED_JOBS_ALERTED").blank?

            Monitoring::PagerDuty.trigger_incident("delayed_jobs/#{Time.now}",{
                :description => "#{DELAYED_JOBS_MSG} #{failed_jobs_count} failed jobs"
            })
            $redis_others.setex("FAILED_JOBS_ALERTED", PAGER_DUTY_FREQUENCY_SECS, true)
        end

    end

    desc "Monitoring growing queue of delayed jobs"
    task :total_jobs => :environment do

        total_jobs_count = Delayed::Job.count

        FreshdeskErrorsMailer.deliver_error_email(nil, nil, nil,{  
            :subject => "#{DELAYED_JOBS_MSG} #{total_jobs_count} jobs are in queue" 
        }) if total_jobs_count >= TOTAL_DELAYED_JOBS_THRESHOULD

        total_mailbox_jobs_count = Mailbox::Job.count
        FreshdeskErrorsMailer.deliver_error_email(nil, nil, nil,{  
            :subject => "#{FAILED_JOBS_ALERTED} #{total_mailbox_jobs_count} jobs are in queue" 
        }) if total_mailbox_jobs_count >= TOTAL_DELAYED_JOBS_THRESHOULD
        
        #For every 5 hours we will init the alert
        if TOTAL_DJ_PAGERDUTY_THRESHOULD <= total_jobs_count and
            $redis_others.get("TOTAL_JOBS_ALERTED").blank?

            Monitoring::PagerDuty.trigger_incident("delayed_jobs/#{Time.now}",{
                :description => "#{DELAYED_JOBS_MSG} #{total_jobs_count} jobs are in queue"
            })
            $redis_others.setex("TOTAL_JOBS_ALERTED", PAGER_DUTY_FREQUENCY_SECS, true)

        end
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
        growing_queue_names = queue_info.keys 
        if $redis_others.get("RESQUEUE_JOBS_ALERTED").blank? and
            (growing_queue_names & PAGERDUTY_QUEUES).size > 0

            Monitoring::PagerDuty.trigger_incident("resque_jobs/#{Time.now}",{
                :description => "Resque is queuing up. Needs your attention!",
                :details => queue_info
            })
            $redis_others.setex("RESQUEUE_JOBS_ALERTED", PAGER_DUTY_FREQUENCY_SECS, true)
        end

    end

    def get_threshold(queue_name)
        return 10 unless Rails.env.production?
        QUEUE_WATCHER_RULE[:threshold][queue_name] || 15000
    end
end


