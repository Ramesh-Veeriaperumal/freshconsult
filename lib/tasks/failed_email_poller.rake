namespace :failed_email_poller do
  
  desc "Fetch failed emails"
  task :poll => :environment do

    include EmailParser

    begin
      $sqs_email_failure_reference.poll(:initial_timeout => false, :batch_size => 10) do |sqs_msg|
        begin
          @args = JSON.parse(sqs_msg.body).deep_symbolize_keys
          Rails.logger.info "FailedEmailPoller: Processing message #{@args}"
          Sharding.select_shard_of(@args[:account_id]) do
            begin
              if valid_params? && valid_message?
                email_failure = Helpdesk::Email::FailedEmailMsg.new(@args)
                email_failure.save! note?
                email_failure.notify
                email_failure.trigger_observer_system_events
              else
                Rails.logger.info "FailedEmailPoller: Invalid message or feature unavailable. #{@args}"
              end
            rescue => e
              error = [@args, e.to_s]
              Rails.logger.info "FailedEmailPoller: Message processing exception - #{error}"
            end
          end
        rescue => e
          Rails.logger.info "FailedEmailPoller: Error processing the account #{@args[:account_id]} - Message :: #{e.message}"
        ensure
          Account.reset_current_account
        end
      end
    rescue => e
      Rails.logger.info "FailedEmailPoller: Error in reading SQS-fd_email_failure_reference - #{e.message}"
    end
  end
end


def valid_params?
  @args[:account_id].present? && @args[:note_id].present? &&
    @args[:email].present? && @args[:published_time].present? &&
      @args[:failure_category].present? && @args[:ticket_id].present?
end

def valid_message?
  return false unless (@account = Account.find_by_id(@args[:account_id]))
  @account.make_current
  valid_failure_category? && email_in_to_or_cc?
end

def note?
  @args[:note_id] != "UNKNOWN"
end

def email_in_to_or_cc?
  @args[:ticket] = Account.current.tickets.find_by_display_id(@args[:ticket_id])
  @args[:object] = note? ? Account.current.notes.where(id: @args[:note_id]).first : @args[:ticket]
  to_emails,cc_emails = @args[:object].to_cc_emails
  (to_emails.present? && to_emails.include?(@args[:email])) ||
    (cc_emails.present? && cc_emails.include?(@args[:email]))
end

def valid_failure_category?
  Helpdesk::Email::Constants::FAILURE_CATEGORY[@args[:failure_category]]
end