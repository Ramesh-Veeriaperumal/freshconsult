class Bot::Cleanup < BaseWorker

  sidekiq_options queue: :bot_cleanup, retry: 0,  failures: :exhausted

  def perform(args = {})
    args.symbolize_keys!
    clear_bot_tickets(args[:bot_id])
    clear_bot_feedbacks(args[:bot_id])
  rescue => e
    NewRelic::Agent.notice_error(e)
    Rails.logger.error("Bot cleanup failure :: Account id : #{Account.current.id} :: Bot id : #{args[:bot_id]}")
    Rails.logger.error("\n#{e.message}\n#{e.backtrace.join("\n\t")}")
  end

  private

    def clear_bot_tickets(bot_id)
      Account.current.bot_tickets.find_each(batch_size: 100, conditions: { bot_id: bot_id } ) do |bot_ticket|
        bot_ticket.destroy
      end
    end

    def clear_bot_feedbacks(bot_id)
      Account.current.bot_feedbacks.find_each(batch_size: 500, conditions: {bot_id: bot_id}) do |bot_feedback|
        bot_feedback.destroy
      end
    end
end
