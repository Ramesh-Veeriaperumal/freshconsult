module SpamDetection

  class SignupRestrictedDomainValidation < BaseWorker
    sidekiq_options :queue => :signup_restricted_domain_validation, :retry => 1, :backtrace => false, :failures => :exhausted

    include EmailHelper
    include Redis::RedisKeys
    include Redis::OthersRedis
    include Email::Antivirus::EHawk
    def perform(args)
      check_and_block_signup_restricted_domains args["account_id"], args["email"], args["call_location"]
    end

    def check_and_block_signup_restricted_domains account_id, email, call_location
      begin
        account = Account.find(account_id)
        domain = email.split("@").last
        if ismember?(SIGNUP_RESTRICTED_EMAIL_DOMAINS, domain)
            
            subject = "Suspicious Spam Account id : #{account.id}"
            additional_info = "Customer's admin email domain is restricted: Account activity #{call_location} : Attempted email_address: #{email}"
            increase_ehawk_spam_score_for_account(4, account, subject, additional_info, ['mail-alerts@freshdesk.com', 'noc@freshdesk.com'])
            Rails.logger.info "Suspending account #{account.id}"
            is_spam_email_account = true
            additional_info = "Reason: Sign up email changed to a spam email domain"
            SendgridDomainUpdates.new().blacklist_spam_account account, is_spam_email_account, additional_info
        end
      rescue Exception => e
        NewRelic::Agent.notice_error(e, {:args => {:account => account,:email => email,:call_location => call_location}})
        raise e
      end
    end

  end
end
