namespace :sidekiq_bg do

  desc "This task fetches sidekiq dead jobs and alerts the team"
  task :fetch_dead_jobs => :environment do
    dead_set = Sidekiq::DeadSet.new
    jobs = dead_set.inject({}) {|result, element| result[element.klass.to_sym] = result[element.klass.to_sym].to_i + 1; result }
    deliver_dead_jobs_list(jobs.sort_by {|_key, value| value}.reverse.to_h)
  end

  task :alert_dead_job_count => :environment do
    dead_set = Sidekiq::DeadSet.new
    max_dead_jobs_count = $redis_others.get("MAX_DEAD_JOBS_ALERT_COUNT") || 5000
    deliver_dead_jobs_count(dead_set.size) if dead_set.size.to_i > max_dead_jobs_count.to_i
  end

  def deliver_dead_jobs_count(count)
    FreshdeskErrorsMailer.deliver_sidekiq_dead_job_count(
      {
        :subject => "Sidekiq Dead jobs alert count",
        :to_email => "freshdesk-core-leads@freshdesk.com",
        :from_email => "venky@freshworks.com",
        :additional_info  => {
          :pod_info => PodConfig['CURRENT_POD'], 
          :count => count.inspect
        }
        
      }
    )
  end

  def deliver_dead_jobs_list(queues_list)
    FreshdeskErrorsMailer.deliver_sidekiq_dead_job_alert(
      {
        :subject => "Sidekiq Dead jobs list",
        :to_email => "freshdesk-core-leads@freshdesk.com",
        :from_email => "venky@freshworks.com",
        :additional_info  => {
          :pod_info => PodConfig['CURRENT_POD'], 
          :queues_list => queues_list.inspect
        }
        
      }
    )
  end


end
