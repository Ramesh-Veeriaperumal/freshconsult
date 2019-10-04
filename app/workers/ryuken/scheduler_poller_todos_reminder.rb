class Ryuken::SchedulerPollerTodosReminder
  include Shoryuken::Worker

  shoryuken_options queue: ::SQS[:fd_scheduler_reminder_todo_queue],
                    body_parser: :json
                    # retry_intervals: [360, 1200, 3600] #=> Depends on visibility timeout
                    # batch: true, #=> Batch processing. Max 10 messages. sqs_msg, args = ARRAY
  def perform(sqs_msg, args)
    begin
      return unless Account.current.todos_reminder_scheduler_enabled?
      @reminder = Account.current.reminders.where(id: args['reminder_id']).first
      if @reminder.blank?
        sqs_msg.try(:delete)
        return true
      end
      @user = Account.current.users.where(id: @reminder.user_id).first
      @ticket = Account.current.tickets.where(id: @reminder.ticket_id).first
      time = format_time(@reminder.reminder_at)
      TodosReminderMailer.send_email(:send_reminder_email, @user, @user, @reminder.body, @ticket, time, @ticket.mint_url)
      data = payload_to_iris
      Iris::Communication.push(IrisNotificationsConfig['api']['collector_path'], data)
      sqs_msg.try(:delete)
      return true
    rescue Exception => e
      Rails.logger.error "Todo Reminder scheduler poller exception - #{e.message} - #{e.backtrace.first}"
      NewRelic::Agent.notice_error(e, { arguments: args })
      raise e
    end
  end

  private

    def format_time(reminder_at)
      Time.use_zone(@user.time_zone) {
        Time.zone.parse(reminder_at.to_s).strftime('%d %b %Y at %I:%M %p') 
      }
    end

    def payload_to_iris
      {
        payload: {
          user_id: @user.id,
          user_name: @user.name,
          todo_id: @reminder.id,
          todo_content: @reminder.body,
          ticket_id: @ticket.display_id,
          ticket_subject: @ticket.subject,
          notification_type: TodoConstants::IRIS_TYPE
        },
        payload_type: TodoConstants::IRIS_TYPE,
        account_id: Account.current.id.to_s
      }
    end

end
