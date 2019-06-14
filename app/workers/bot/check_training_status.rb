class Bot::CheckTrainingStatus < BaseWorker
  include Redis::RedisKeys
  include Redis::OthersRedis

  sidekiq_options queue: :check_bot_training, retry: 0,  failures: :exhausted

  def perform(args)
    args.symbolize_keys!
    status_key = BOT_STATUS % { account_id: Account.current.id, bot_id: args[:bot_id] }
    if get_others_redis_key(status_key).to_i == BotConstants::BOT_STATUS[:training_inprogress]
      Rails.logger.info("Bot Training Incomplete :: Account id : #{Account.current.id} :: Bot id : #{args[:bot_id]}")
      ::Admin::BotMailer.send(:bot_training_incomplete_email, args)
    else
      Rails.logger.info("Bot Training Completed :: Account id : #{Account.current.id} :: Bot id : #{args[:bot_id]}")
    end
  rescue => e
    NewRelic::Agent.notice_error(e, description: "Error in checking bot training status for bot id #{args[:bot_id]}")
    Rails.logger.error("Bot CheckTrainingStatus Failure :: Account id : #{Account.current.id} :: Bot id : #{args[:bot_id]}")
    Rails.logger.error("\n#{e.message}\n#{e.backtrace.join("\n\t")}")
  end
end
