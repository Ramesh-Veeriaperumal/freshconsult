namespace :sidekiq_bg do

  desc "This task fetches sidekiq dead jobs and alerts the team"
  task :fetch_dead_jobs => :environment do
    dead_set = Sidekiq::DeadSet.new
    max_dead_jobs_count = $redis_others.get("MAX_DEAD_JOBS_ALERT_COUNT") || 5000
    if dead_set.size.to_i > max_dead_jobs_count.to_i
      jobs = dead_set.inject({}) {|result, element| result[element.klass.to_sym] = result[element.klass.to_sym].to_i + 1; result }
      deliver_dead_jobs_list(jobs.sort_by {|_key, value| value}.reverse.to_h, dead_set.size.to_i)
    end
  end

  def deliver_dead_jobs_list(queues_list, jobs_size)
    FreshdeskErrorsMailer.deliver_sidekiq_dead_job_alert(
      {
        :subject => "Sidekiq Dead jobs list",
        :to_email => "freshdesk-core-dev@freshdesk.com",
        :from_email => "venky@freshworks.com",
        :additional_info  => {
          :pod_info => PodConfig['CURRENT_POD'], 
          :queues_list => queues_list.inspect,
          :dead_jobs_size => jobs_size
        }
        
      }
    )
  end
end
