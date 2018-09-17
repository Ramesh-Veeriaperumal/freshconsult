class AgentDestroyCleanup < BaseWorker

  include Redis::RedisKeys
  include Redis::SortedSetRedis
  include MemcacheKeys

  sidekiq_options :queue => :agent_destroy_cleanup, :retry => 0, :backtrace => true, :failures => :exhausted

  USER_ASSOCIATED_MODELS = [:report_filters, :user_skills, :ticket_subscriptions, :email_notification_agents]
  
  attr_accessor :args

  def perform(args)
    begin
      args.symbolize_keys!
      @args    = args
      @account = Account.current
      if args[:user_id].present?
        @user = @account.users.find_by_id args[:user_id]
        destroy_agents_personal_items
        delete_user_associated
        delete_user_from_leaderboard
        clear_leaderboard_response_cache
      end
    rescue Exception => e
      puts e.inspect, args.inspect
      NewRelic::Agent.notice_error(e, {:args => args})
    end
  end

  private

    def destroy_agents_personal_items # destroy agents personal canned_responses,scn_automations,tkt_templates
      ["canned_responses","scn_automations","ticket_templates"].each do |items|
        @account.safe_send(items).only_me(@user).destroy_all if @user.present?
      end
    end

    def delete_user_associated
      USER_ASSOCIATED_MODELS.each do |model|
        @account.safe_send(model).where(:user_id => args[:user_id]).destroy_all
      end
    end

    def delete_user_from_leaderboard
      user = @account.users.find_by_id(args[:user_id])
      group_ids = user.agent_groups.pluck(:group_id)
      (0..3).each do |months_counter|
        delete_month = months_counter.month.ago(Time.now.in_time_zone(@account.time_zone)).month
        [:mvp, :love, :sharpshooter, :speed].each do |category|
          key = agents_leaderboard_key @account.id, category, delete_month
          delete_member_sorted_set_redis key, args[:user_id]

          group_ids.each do |group_id|
            group_agents_key = group_agents_leaderboard_key @account.id, category, delete_month, group_id
            delete_member_sorted_set_redis group_agents_key, args[:user_id]
          end
        end
      end
    end

    def agents_leaderboard_key account_id, category, month
      GAMIFICATION_AGENTS_LEADERBOARD % { :account_id => account_id, :category => category, :month => month }
    end

    def group_agents_leaderboard_key account_id, category, month, group_ids
      GAMIFICATION_GROUP_AGENTS_LEADERBOARD % { :account_id => account_id, :category => category, :month => month, :group_id => group_id }
    end

    def clear_leaderboard_response_cache
      users = @account.technicians.includes(:agent_groups).find(:all)
      users.each do |user|
        MemcacheKeys.delete_from_cache(account_leaderboard_widget_cache_key(user.id))
        user.agent_groups.each do |agent_group|
          MemcacheKeys.delete_from_cache(group_agents_leaderboard_widget_cache_key(user.id, agent_group.group_id))
        end
      end
    end

    def group_agents_leaderboard_widget_cache_key(user_id, group_id)
      GROUP_AGENTS_LEADERBOARD_MINILIST_REALTIME_FALCON % { account_id: @account.id, user_id: user_id, group_id: group_id }
    end

    def account_leaderboard_widget_cache_key(user_id)
      LEADERBOARD_MINILIST_REALTIME_FALCON % { account_id: @account.id, user_id: user_id }
    end
end
