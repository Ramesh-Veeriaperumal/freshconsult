module SpamDetection
	class DataMigration < BaseWorker

		sidekiq_options :queue => :spam_data_migration, :retry => 3, :failures => :exhausted

		STARTING_TIME_RANGE = 5 # in days
		MAX_TIME_RANGE = 30 # in days
		MAX_COUNT = 200

		def perform
			Sharding.select_shard_of(Account.current.id) do
				Sharding.run_on_slave do
					account = Account.current
					if account.present? and account.active?
						Rails.logger.info "Migrating spam data for the Account ID : #{account.id}"
						[:spam, :ham].each do |type|
							migrate_account_data(account, Helpdesk::Email::Constants::MESSAGE_TYPE_BY_NAME[type])
						end
					end
				end
			end
		rescue Exception => e
			Rails.logger.info "Exception while migrating spam data #{e.message} - #{e.backtrace}"
		end

		def migrate_account_data(account, type)
			time_range = STARTING_TIME_RANGE
			count = 0
			while time_range <= MAX_TIME_RANGE do
				count += learn_data(account, time_range, type)
				time_range += 5
				break if count >= MAX_COUNT
			end
			spam = (type == 1) ? 'spam' : 'ham'
			Rails.logger.info "Total #{spam} tickets learned for Account ID #{account.id}: #{count}"
		end

		def learn_data(account, time, type)
			mthd = (type == 1) ? 'learn_spam' : 'learn_ham'
			count = 0
			account.tickets.find_in_batches(:batch_size => 100, :conditions => 
				{ :created_at => (time.days.ago..(time - 5).days.ago), :spam => type}) do |tickets|
				count += tickets.size
				tickets.each do |tkt|
					params = {:from => tkt.requester.email, :to => tkt.to_email, :subject => tkt.subject, :text =>tkt.description, :html => tkt.description_html,
					 :message_id => "#{Mail.random_tag}.#{::Socket.gethostname}@spamreport.freshdesk.com"}
					mail = Helpdesk::Email::SpamDetector.construct_raw_mail(params)
					sds = FdSpamDetectionService::Service.new(account.id, mail.to_s)
					sds.safe_send(mthd)
				end
				break if count >= MAX_COUNT
			end
			return count
		end

	end
end
