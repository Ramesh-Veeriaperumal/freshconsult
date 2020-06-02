class Ryuken::DeleteSpamTrashTicket
  include Shoryuken::Worker
  include Utils::Freno
  include SqsHelperMethods

  shoryuken_options queue: [::SQS[:spam_trash_delete_free_acc_queue], ::SQS[:spam_trash_delete_paid_acc_queue]], body_parser: :json

  APPLICATION_NAME = 'DeleteSpamTicketsCleanup'.freeze
  NUMBER_OF_DAYS = 30

  def perform(sqs_msg, args)
    return sqs_msg.try(:delete) unless Account.current.delete_trash_daily_enabled?

    number_of_days = Account.current.account_additional_settings.delete_spam_tickets_days || NUMBER_OF_DAYS
    ticket = Account.current.tickets.find_by_id(args['ticket_id'])
    return sqs_msg.try(:delete) unless ticket && ticket.spam_or_deleted? && ticket.updated_at < number_of_days.days.ago

    shard_name = ActiveRecord::Base.current_shard_selection.shard.to_s
    lag = get_replication_lag_for_shard(APPLICATION_NAME, shard_name, 5.seconds)
    lag > 0 ? rerun_after(sqs_msg, lag, shard_name) : ticket.destroy
    sqs_msg.try(:delete)
  rescue StandardError => e
    Rails.logger.error "Delete spam/trash ticket performer exception - #{e.message} - #{e.backtrace.first}"
    NewRelic::Agent.notice_error(e, arguments: args)
    raise e
  end

  private

    def rerun_after(sqs_msg, lag, shard_name)
      Rails.logger.debug("Warning: Freno: Ryuken::DeleteSpamTrashTicket: replication lag: #{lag} secs :: shard :: #{shard_name}")
      requeue(sqs_msg.queue_name, JSON.parse(sqs_msg.body), { requeue_limit: 5, requeue_delay: [60, lag].max })
    end
end
