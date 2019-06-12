class Ryuken::DeleteSpamTrashTicket
  include Shoryuken::Worker
  shoryuken_options queue: ::SQS[:spam_trash_delete_queue], body_parser: :json

  NUMBER_OF_DAYS = 30

  def perform(sqs_msg, args)
    return sqs_msg.try(:delete) unless Account.current.delete_trash_daily_enabled?

    number_of_days = Account.current.account_additional_settings.delete_spam_tickets_days || NUMBER_OF_DAYS
    ticket = Account.current.tickets.find_by_id(args['ticket_id'])
    ticket.destroy if ticket && ticket.spam_or_deleted? && ticket.updated_at < number_of_days.days.ago
    sqs_msg.try(:delete)
  rescue StandardError => e
    Rails.logger.error "Delete spam/trash ticket performer exception - #{e.message} - #{e.backtrace.first}"
    NewRelic::Agent.notice_error(e, arguments: args)
    raise e
  end
end
