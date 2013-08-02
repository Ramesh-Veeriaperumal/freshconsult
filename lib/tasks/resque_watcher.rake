FAILED_JOBS_THRESHOLD = 500
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

namespace :resque_watcher do 
    desc 'To keep a tab on resque failed jobs'
    task :failed_jobs => :environment do
        failed_jobs_count = Resque::Failure.count
        FreshdeskErrorsMailer.deliver_error_email(nil, nil, nil,
            {  :subject => "Resque needs your attention #{failed_jobs_count} failed jobs" }
        ) if failed_jobs_count >= FAILED_JOBS_THRESHOLD
    end

    desc "Monitoring growing queue on resque"
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


