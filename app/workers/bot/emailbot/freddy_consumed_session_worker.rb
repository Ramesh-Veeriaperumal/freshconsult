# frozen_string_literal: true

class Bot::Emailbot::FreddyConsumedSessionWorker < BaseWorker
  include Sidekiq::Worker
  sidekiq_options queue: :freddy_consumed_session_queue, retry: 0, failures: :exhausted

  def perform(args)
    FreddyConsumedSessionMailer.send_email_to_group(:send_consumed_session_remainder,
                                                    Account.current.fetch_all_account_admin_email, args.symbolize_keys[:sessions_consumed], args.symbolize_keys[:sessions_count])
  rescue StandardError => e
    Rails.logger.error "Error in sending freddy session consumed email notification - #{Account.current.id} - args #{args} -#{e.message} - #{e.backtrace.first}"
  end
end
