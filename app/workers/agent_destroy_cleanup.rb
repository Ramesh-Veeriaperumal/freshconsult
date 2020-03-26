class AgentDestroyCleanup < BaseWorker

  include Redis::RedisKeys
  include Redis::SortedSetRedis
  include MemcacheKeys

  sidekiq_options :queue => :agent_destroy_cleanup, :retry => 0, :failures => :exhausted

  USER_ASSOCIATED_MODELS = [:report_filters, :user_skills, :ticket_subscriptions, :email_notification_agents]
  
  attr_accessor :args

  def perform(args)
    begin
      args.symbolize_keys!
      @args    = args
      @account = Account.current
      if args[:user_id].present?
        @user = @account.users.find_by_id args[:user_id]
        destory_support_scores_in_batches
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

    def destory_support_scores_in_batches
      @account.support_scores.where(user_id: args[:user_id]).find_in_batches(batch_size: 300) do |support_scores_data|
        @account.support_scores.where(user_id: args[:user_id]).where('id in (?)', support_scores_data.map(&:id)).delete_all
      end
    end

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

    # Clearing leaderboard redis sorted set and cache.
    def delete_user_from_leaderboard
      group_ids = @account.groups_from_cache.map(&:id)
      (0..3).each do |months_counter|
        delete_month = months_counter.month.ago(Time.now.in_time_zone(@account.time_zone)).month
        [:mvp, :love, :sharpshooter, :speed].each do |category|
          key = agents_leaderboard_redis_key @account.id, category, delete_month
          MemcacheKeys.delete_from_cache(key)
          delete_member_sorted_set_redis key, args[:user_id]

          group_ids.each do |group_id|
            group_agents_key = group_agents_leaderboard_redis_key @account.id, category, delete_month, group_id
            MemcacheKeys.delete_from_cache(group_agents_key)
            delete_member_sorted_set_redis group_agents_key, args[:user_id]
          end
        end
      end
    end

    # Redis key is also used as cache key between redis and db.
    def agents_leaderboard_redis_key(account_id, category, month)
      GAMIFICATION_AGENTS_LEADERBOARD % { :account_id => account_id, :category => category, :month => month }
    end

    def group_agents_leaderboard_redis_key(account_id, category, month, group_id)
      GAMIFICATION_GROUP_AGENTS_LEADERBOARD % { :account_id => account_id, :category => category, :month => month, :group_id => group_id  }
    end

    # Clearing Leaderboard API response cache.
    def clear_leaderboard_response_cache
      users = @account.technicians.includes(:agent_groups).to_a
      users.each do |user|
        MemcacheKeys.delete_from_cache(account_leaderboard_widget_cache_key(@account.id, user.id))
        user.agent_groups.each do |agent_group|
          MemcacheKeys.delete_from_cache(group_agents_leaderboard_widget_cache_key(@account.id, user.id, agent_group.group_id))
        end
      end
    end

    def group_agents_leaderboard_widget_cache_key(account_id, user_id, group_id)
      GROUP_AGENTS_LEADERBOARD_MINILIST_REALTIME_FALCON % { account_id: account_id, user_id: user_id, group_id: group_id }
    end

    def account_leaderboard_widget_cache_key(account_id, user_id)
      LEADERBOARD_MINILIST_REALTIME_FALCON % { account_id: account_id, user_id: user_id }
    end
end
