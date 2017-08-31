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
        restricted_domains = $redis_others.lrange("SIGNUP_RESTRICTED_DOMAINS", 0, -1)
        domain = email.split("@").last
        if restricted_domains.any?{|d| d.include?(domain)}
            
            subject = "Suspicious Sapm Account id : #{account.id}"
            additional_info = "Customer's admin email domain is restricted: Account activity #{call_location} : Attempted email_address: #{email}"
            # notify_account_blocks(account, subject, additional_info)
            # update_freshops_activity(account, "Account blocked during #{call_location} due to restricted domain", "block_account")
            increase_ehawk_spam_score_for_account(4, @account, subject, additional_info)      
            Rails.logger.info "Suspending account #{account.id}"
        end
      rescue Exception => e
        NewRelic::Agent.notice_error(e, {:args => {:account => account,:email => email,:call_location => call_location}})
        raise e
      end
    end

  end
end
