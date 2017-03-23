namespace :failed_email_poller do
  
  desc "Fetch failed emails"
  task :poll => :environment do
    begin
      $sqs_email_failure_reference.poll(:initial_timeout => false, :batch_size => 10) do |sqs_msg|
        puts "FailedEmailPoller:: Poller ::: #{sqs_msg}"
        begin
          @args = JSON.parse(sqs_msg.body).deep_symbolize_keys
          puts "FailedEmailPoller:: args ::: #{@args}"
            Sharding.select_shard_of(@args[:account_id]) do
              if valid_params? && valid_message?
                puts "FailedEmailPoller:: Processing message"
                email_failure = Helpdesk::Email::FailedEmailMsg.new(@args)
                email_failure.save!
                email_failure.notify
              else
                puts "FailedEmailPoller:: Invalid message or feature not set. #{@args}"
                Rails.logger.info "FailedEmailPoller:: Invalid message or feature not set. #{@args}"
              end
            end
        rescue => e
          error = [@args, e.to_s]
          puts "FailedEmailPoller:: Msg processing exception - #{error}"
          Rails.logger.info "FailedEmailPoller:: Msg processing exception - #{error}"
        ensure
          Account.reset_current_account
        end
      end
    rescue => e
      Rails.logger.info "FailedEmailPoller:: Error in reading SQS-fd_email_failure_reference - #{e.message}"
      puts "FailedEmailPoller:: Error in reading SQS-fd_email_failure_reference - #{e.message}"
    end
  end
end


def valid_params?
  @args[:account_id].present? && @args[:note_id].present? && @args[:email].present? && @args[:published_time].present? && @args[:failure_category].present?
end

def valid_message?
  return false unless (@account = Account.find_by_id(@args[:account_id]))
  @account.make_current
  email_failure_feature_enabled? && valid_note? && valid_failure_category?
end

def email_failure_feature_enabled?
  @account.email_failures_enabled?
end

def valid_note?
  note = Account.current.notes.where(id: @args[:note_id]).first
  if note 
    to_emails = note.to_emails || []
    cc_emails = note.cc_emails || []
    to_emails.include?(@args[:email]) || cc_emails.include?(@args[:email])
  else
    false
  end
end

def valid_failure_category?
  Helpdesk::Email::Constants::FAILURE_CATEGORY[@args[:failure_category]]
end