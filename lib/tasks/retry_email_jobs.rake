namespace :retry_email_jobs do

	desc "push the hourly path to s3 retry worker"
	task :start => :environment do
		loop do
			Helpdesk::EmailHourlyUpdate.process_failed_emails
			Rails.logger.info "Process sleeping for 30 minutes"
			sleep(30.minutes)
		end
	end

end


