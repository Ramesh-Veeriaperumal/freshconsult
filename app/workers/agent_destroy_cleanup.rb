class AgentDestroyCleanup < BaseWorker

  include Redis::RedisKeys
  include Redis::SortedSetRedis

  sidekiq_options :queue => :agent_destroy_cleanup, :retry => 0, :backtrace => true, :failures => :exhausted

  USER_ASSOCIATED_MODELS = [:report_filters, :user_skills]
  
  attr_accessor :args

  def perform(args)
    begin
      args.symbolize_keys!
      @args    = args
      @account = Account.current
      if args[:user_id].present?
        destroy_agents_personal_items
        delete_user_associated
        delete_user_from_leaderboard
      end
    rescue Exception => e
      puts e.inspect, args.inspect
      NewRelic::Agent.notice_error(e, {:args => args})
    end
  end

  private

    def destroy_agents_personal_items # destroy agents personal canned_responses,scn_automations,tkt_templates
      user = @account.users.find_by_id args[:user_id]
      ["canned_responses","scn_automations","ticket_templates"].each do |items|
        @account.send(items).only_me(user).destroy_all if user.present?
      end
    end

    def delete_user_associated
      USER_ASSOCIATED_MODELS.each do |model|
        @account.send(model).where(:user_id => args[:user_id]).destroy_all
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

