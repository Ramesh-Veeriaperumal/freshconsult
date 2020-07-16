namespace :spam_reports do

	desc "Learning spam emails from the feedback provided email servers"
	task :learn => :environment do

		include Redis::OthersRedis
		include Redis::RedisKeys
    include Helpdesk::Email::OutgoingCategory

    SPAM_REPORTS_LIMIT = { :trial => 5, :free => 5, :default => 5, :active => 10, :premium => 20 }

		sqs_spam_reports = AWS::SQS.new.queues.named(SQS[:email_events_queue])
		sqs_spam_reports.poll(:initial_timeout => false) do |sqs_msg|
      begin
      	args = JSON.parse(sqs_msg.body)
        learn_mail(args)
      rescue => e
      	Rails.logger.info "Error while processing sqs request- #{e.message} - #{e.backtrace}"
      end
    end
	end

end

def learn_mail(args)
	args.each do |sg_evt|
    if (sg_evt['event'] == "spam")
		  learn_spam(sg_evt.merge(:to => sg_evt['email'], :from => sg_evt['from_email']).with_indifferent_access) 
    end
	end
end

def learn_spam(params)
  Sharding.select_shard_of(params[:account_id]) do
    account = Account.find_by_id(params[:account_id])
    account.make_current
    key = SPAM_REPORTS_COUNT % { :account_id => account.id }
    if redis_key_exists?(key)
      count = increment_others_redis(key)
      state = get_subscription
      unless state != "spam" && $spam_limit.present? && $spam_limit[state.to_sym].blank?
        spam_limit_key = MAX_SPAM_REPORTS_ALLOWED % { :state => state }
        limit = get_others_redis_key(spam_limit_key)
        $spam_limit = Hash.new
        $spam_limit[state.to_sym] = limit ? limit.to_i : SPAM_REPORTS_LIMIT[state.to_sym]
      end
      blacklist_account(account) if (!account.launched?(:spam_blacklist_feature) && count >= $spam_limit[state.to_sym])
    else
      set_others_redis_key(key, 1, nil)
    end
    email = construct_email(account, params)
    result = FdSpamDetectionService::Service.new(Helpdesk::EMAIL[:outgoing_spam_account], email).learn_spam
    Account.reset_current_account
    Rails.logger.info "Response for learning spam: #{result}"
  end
end

def construct_email(account, params)
	if (params[:note_id].present? && params[:note_id] != -1)
		note = Helpdesk::Note.find_by_account_id_and_id(account.id, params[:note_id])
    subject = note.subject
    content = note.full_text_html
	elsif (params[:ticket_id].present? && params[:ticket_id] != -1)
		tkt = Helpdesk::Ticket.find_by_account_id_and_display_id(account.id, params[:ticket_id])
    subject = tkt.subject
    content = tkt.description_html
	end
  email = Mail.new do 
    from        params[:from]
    to          params[:to]
    subject     subject
    body        content
    message_id  "#{Mail.random_tag}.#{::Socket.gethostname}@spamreport.freshdesk.com"
  end.to_s
end

def blacklist_account(account)
  account.launch(:spam_blacklist_feature)
  Rails.logger.info "Blacklisted suspicious spam account: #{account.id}"
  FreshdeskErrorsMailer.error_email(nil, {:domain_name => account.full_domain}, nil, {
      :subject => "Blacklisted suspicious spam account :#{account.id} ", 
      :recipients => ["mail-alerts@freshdesk.com", "noc@freshdesk.com","helpdesk@noc-alerts.freshservice.com"],
      :additional_info => {:info => "Too many spam reports for the account"}
    })
end