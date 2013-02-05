FAILED_JOBS_THRESHOLD = 500

namespace :resque_watcher do 
	desc 'To keep a tab on resque failed jobs'
	task :failed_jobs => :environment do
		 failed_jobs_count = Resque::Failure.count
    	 FreshdeskErrorsMailer.deliver_error_email(nil, nil, nil,
     	{  :subject => "Resque needs your attention #{failed_jobs_count} failed jobs" }
     	) if failed_jobs_count >= FAILED_JOBS_THRESHOLD
	end
end


