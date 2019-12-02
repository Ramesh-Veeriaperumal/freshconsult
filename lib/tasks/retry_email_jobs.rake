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

namespace :retry_failed_emails do

	desc "retry failed emails"
	task :start => :environment do
		loop do
			begin
				Helpdesk::Email::RetryEmailWorker.retry_failed_emails
			rescue => e
			    Rails.logger.info "Caught exception in retry_failed_emails rake - #{e.message} - #{e.backtrace}"
			    NewRelic::Agent.notice_error(e, {:description => "Caught exception in retry_failed_emails rake"})
      ensure
				Rails.logger.info "Process sleeping for 5 minutes"
				sleep(5.minutes)
			end
		end
	end

end


