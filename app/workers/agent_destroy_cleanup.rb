class AgentDestroyCleanup < BaseWorker

  include Redis::RedisKeys
  include Redis::SortedSetRedis

  sidekiq_options :queue => :agent_destroy_cleanup, :retry => 0, :backtrace => true, :failures => :exhausted

  USER_ASSOCIATED_MODELS = [:report_filters]
  
  attr_accessor :args

  def perform(args)
    begin
      args.symbolize_keys!
      @args    = args
      @account = Account.current
      delete_user_associated
      delete_user_from_leaderboard
    rescue Exception => e
      puts e.inspect, args.inspect
      NewRelic::Agent.notice_error(e, {:args => args})
    end
  end

  private

    def delete_user_associated
      USER_ASSOCIATED_MODELS.each do |model|
        @account.send(model).where(:user_id => args[:user_id]).destroy_all if args[:user_id].present?
      end
    end

    def delete_user_from_leaderboard
      (0..3).each do |months_counter|
        delete_month = months_counter.month.ago(Time.now.in_time_zone(@account.time_zone)).month
        [:mvp, :love, :sharpshooter, :speed].each do |category|
          key = agents_leaderboard_key @account.id, category, delete_month

          delete_member_sorted_set_redis key, args[:user_id]
        end
      end
    end

    def agents_leaderboard_key account_id, category, month
      GAMIFICATION_AGENTS_LEADERBOARD % { :account_id => account_id, :category => category, :month => month }
    end
end

