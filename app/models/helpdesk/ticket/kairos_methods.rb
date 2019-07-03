class Helpdesk::Ticket < ActiveRecord::Base
  after_commit ->(obj) { obj.trigger_ticket_delete_scheduler }, on: :create, if: :ticket_delete_or_spam?
  after_commit ->(obj) { obj.trigger_ticket_delete_scheduler }, on: :update, if: :ticket_delete_or_spam?
  after_commit ->(obj) { obj.cancel_ticket_delete_scheduler }, on: :update, if: :ticket_restored?
  after_commit ->(obj) { obj.cancel_ticket_delete_scheduler }, on: :destroy

  def trigger_ticket_delete_scheduler
    return unless Account.current.delete_trash_daily_schedule_enabled?

    payload = {
      job_id: job_id,
      message_type: ApiTicketConstants::TICKET_DELETE_MESSAGE_TYPE,
      group: ::SchedulerClientKeys['ticket_delete_group_name'],
      scheduled_time: (Time.now + (Account.current.account_additional_settings.delete_spam_tickets_days || ApiTicketConstants::TICKET_DELETE_DAYS).days + 12.hours).to_datetime,
      data: {
        account_id: Account.current.id,
        ticket_id: id,
        enqueued_at: Time.now.to_i,
        scheduler_type: ApiTicketConstants::TICKET_DELETE_SCHEDULER_TYPE
      },
      sqs: {
        url: delete_sqs_queue_url
      }
    }
    ::Scheduler::PostMessage.perform_async(payload: payload)
  end

  def cancel_ticket_delete_scheduler
    ::Scheduler::CancelMessage.perform_async(job_ids: Array(job_id), group_name: ::SchedulerClientKeys['ticket_delete_group_name']) if Account.current.delete_trash_daily_schedule_enabled?
  end

  private

    def job_id
      [Account.current.id, 'ticket', id].join('_')
    end

    def delete_sqs_queue_url
      Account.current.paid_account? ? SQS_V2_QUEUE_URLS[SQS[:spam_trash_delete_paid_acc_queue]] : SQS_V2_QUEUE_URLS[SQS[:spam_trash_delete_free_acc_queue]]
    end
end
