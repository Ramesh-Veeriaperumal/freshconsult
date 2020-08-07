DELAYED_JOB_QUEUES =  YAML::load(ERB.new(File.read("#{Rails.root}/config/delayed_job_watcher.yml")).result)[Rails.env]
DELAYED_JOBS_MSG = "Queue's jobs needs your attention!"

PAGER_DUTY_FREQUENCY_SECS = Rails.env.production? ? 18000 : 900 #5 hours : # 15 mins
PAGERDUTY_QUEUES = [
    "observer_worker","update_ticket_states_queue"
]

FAILED_RESQUE_JOBS_THRESHOLD = 500
QUEUE_WATCHER_RULE = {
    :threshold => {
        "observer_worker" => 5000,
        "update_ticket_states_queue" => 5000,
        "premium_supervisor_worker" => 5000,
        "es_index_queue" => 10000,
        "sla_worker" => 25000,
        "free_sla_worker" => 25000,
        "trail_sla_worker" => 25000,
        "Salesforcequeue" => 1000
    } ,
    :except => ["supervisor_worker",
              "gamification_ticket_quests",
              "gamification_ticket_score",
              "gamification_user_score",
              "livechat_queue"  
            ]
}


namespace :delayedjobs_watcher do 
    desc 'To keep a tab on failed delayed jobs '
    task :failed_jobs => :environment do
      DELAYED_JOB_QUEUES.each do |queue, config|
          
        queue = queue.capitalize
        failed_jobs_count = Object.const_get("#{queue}::Job").count(
          :conditions => ["last_error is not null and attempts > 1"]
        )

        FreshdeskErrorsMailer.deliver_error_email(nil, nil, nil, {
          :subject => "#{queue} #{DELAYED_JOBS_MSG} #{failed_jobs_count} failed jobs in #{PodConfig['CURRENT_POD']}"
        }) if failed_jobs_count >= config["failed"]

        #For every 5 hours we will init the alert
        if config["pg_duty_failed"] <= failed_jobs_count and 
          $redis_others.perform_redis_op("get", "#{queue.upcase}_FAILED_JOBS_ALERTED").blank?

          Monitoring::PagerDuty.trigger_incident("delayed_jobs/#{Time.now}",{
            :description => "#{queue} #{DELAYED_JOBS_MSG} #{failed_jobs_count} failed jobs"
          })
          $redis_others.perform_redis_op("setex", "#{queue.upcase}_FAILED_JOBS_ALERTED", PAGER_DUTY_FREQUENCY_SECS, true)
        end
      end
    end

    desc "Monitoring growing queue of enqueued jobs"
    task :total_jobs => :environment do
      DELAYED_JOB_QUEUES.each do |queue,config|

        queue = queue.capitalize
        total_jobs_count = Object.const_get("#{queue}::Job").count(
          :conditions => ["created_at = run_at and attempts=0"]
        )
    
        FreshdeskErrorsMailer.deliver_error_email(nil, nil, nil, {
          :subject => "#{queue} #{DELAYED_JOBS_MSG} #{total_jobs_count} enqueued jobs are in queue in #{PodConfig['CURRENT_POD']}" 
        }) if total_jobs_count >= config["total"]

        #For every 5 hours we will init the alert
        if config["pg_duty_total"]  <= total_jobs_count and 
          $redis_others.perform_redis_op("get", "#{queue.upcase}_TOTAL_JOBS_ALERTED").blank?

          Monitoring::PagerDuty.trigger_incident("delayed_jobs/#{Time.now}",{
            :description => "#{queue} #{DELAYED_JOBS_MSG} #{total_jobs_count} enqueued jobs are in queue"
          })
          $redis_others.perform_redis_op("setex", "#{queue.upcase}_TOTAL_JOBS_ALERTED", PAGER_DUTY_FREQUENCY_SECS, true)
        end
      end
    end
    
    desc "Monitoring growing queue of scheduled jobs"
    task :scheduled_jobs => :environment do
      DELAYED_JOB_QUEUES.each do |queue,config|

        queue = queue.capitalize
        total_jobs_count = Object.const_get("#{queue}::Job").count(
          :conditions => ["created_at != run_at and attempts=0"]
        )
    
        FreshdeskErrorsMailer.deliver_error_email(nil, nil, nil, {
          :subject => "#{queue} #{DELAYED_JOBS_MSG} #{total_jobs_count} scheduled jobs are in queue in #{PodConfig['CURRENT_POD']}" 
        }) if total_jobs_count >= config["total"]

        #For every 5 hours we will init the alert
        if config["pg_duty_total"]  <= total_jobs_count and 
          $redis_others.perform_redis_op("get", "#{queue.upcase}_TOTAL_JOBS_ALERTED").blank?

          Monitoring::PagerDuty.trigger_incident("delayed_jobs/#{Time.now}",{
            :description => "#{queue} #{DELAYED_JOBS_MSG} #{total_jobs_count} scheduled jobs are in queue"
          })
          $redis_others.perform_redis_op("setex", "#{queue.upcase}_TOTAL_JOBS_ALERTED", PAGER_DUTY_FREQUENCY_SECS, true)
        end
      end
    end

  desc "Moving the jobs delayed jobs to backup queue."
  task :move_delayed_jobs => :environment do
     count = Delayed::Job.count
     total = 0
     while count > 250 do
       ActiveRecord::Base.connection.execute('UPDATE delayed_jobs SET run_at= NOW() + INTERVAL 1 WEEK ORDER BY ID LIMIT 500;')
       ActiveRecord::Base.connection.execute('INSERT INTO delayed_jobs3 SELECT * FROM delayed_jobs WHERE run_at > NOW() + INTERVAL 5 DAY ORDER BY ID LIMIT 500;')
       ActiveRecord::Base.connection.execute('DELETE FROM delayed_jobs WHERE run_at > NOW() + INTERVAL 5 DAY ORDER BY ID LIMIT 500;')
       total += (count > 500 ? 500 : count)
       count = Delayed::Job.count
    end
    FreshdeskErrorsMailer.deliver_error_email(nil, nil, nil, {
         :subject => "Moved #{total} delayed jobs to backup queue in #{PodConfig['CURRENT_POD']}",
         :recipients => "mail-alerts@freshdesk.com"
       }) if total > 0    
  end

end

namespace :resque_watcher do 
    desc 'To keep a tab on resque failed jobs'
    task :failed_jobs => :environment do

        failed_jobs_count = Resque::Failure.count
        FreshdeskErrorsMailer.error_email(nil, nil, nil,
            {  :subject => "Resque needs your attention #{failed_jobs_count} failed jobs in #{PodConfig['CURRENT_POD']}" }
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
        
        FreshdeskErrorsMailer.error_email(nil, nil, nil,details_hash) unless queue_info.empty?
        growing_queue_names = queue_info.keys 
        if $redis_others.perform_redis_op("get", "RESQUEUE_JOBS_ALERTED").blank? and
            (growing_queue_names & PAGERDUTY_QUEUES).size > 0

            Monitoring::PagerDuty.trigger_incident("resque_jobs/#{Time.now}",{
                :description => "Resque is queuing up. Needs your attention!",
                :details => queue_info
            })
            $redis_others.perform_redis_op("setex", "RESQUEUE_JOBS_ALERTED", PAGER_DUTY_FREQUENCY_SECS, true)
        end

    end

    def get_threshold(queue_name)
        return 10 unless Rails.env.production?
        QUEUE_WATCHER_RULE[:threshold][queue_name] || 15000
    end
end


