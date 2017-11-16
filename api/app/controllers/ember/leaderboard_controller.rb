module Ember
  class LeaderboardController < ApiApplicationController
    include ApiLeaderboardConstants
    include Redis::RedisKeys
    include Redis::SortedSetRedis

    around_filter :run_on_slave
    def agents
      if params[:mini_list].present?
        mini_list
      else
        @leaderboard = {}
      end
    end

    def set_root_key
      response.api_root_key = ROOT_KEY[action_name.to_sym]
    end

    def feature_name
      :gamification
    end

    private

      def mini_list
        leaderboard = MemcacheKeys.fetch(LEADERBOARD_MINILIST_REALTIME_FALCON % { account_id: Account.current.id, user_id: User.current.id }, 1.hour.to_i) do
          mini_list = []
          category_list.each do |category|
            form_category_hash(category, mini_list)
          end
          mini_list
        end
        @leaderboard = leaderboard.presence || []
      end

      def form_category_hash(category, mini_list)
        support_score = SupportScore.new
        response = support_score.get_mini_list current_account, current_user, category, 'v2'
        return if response.nil?
        category_hash = {}
        user = current_account.technicians.includes(:avatar).find(response.first.first)
        category_hash[:name] = category.to_s
        category_hash[:id]   = mini_list.length + 1
        leader_hash = leader_hash_object category, response.first.second, user
        category_hash[:rank_holders] = []
        category_hash[:rank_holders] << leader_hash
        other_rank_holders_objects response.second, category_hash[:rank_holders], category
        mini_list << category_hash
      end

      def other_rank_holders_objects(leaderboard_agents, category_list, category)
        leaderboard_agents.each do |leaderboard_agent|
          category_list << {
            id: "#{category}_#{leaderboard_agent.last}",
            rank: leaderboard_agent.last,
            score: leaderboard_agent.second
          }.merge(user_id_avatar_hash(current_account.technicians.includes(:avatar).find(leaderboard_agent.first)))
        end
      end

      def leader_hash_object(category, score, user)
        {
          id: "#{category}_1",
          rank: 1,
          score: score
        }.merge(user_id_avatar_hash(user))
      end

      def category_list
        categories = CATEGORY_LIST.dup
        categories.insert(1, :love) if current_account.any_survey_feature_enabled_and_active?
        categories
      end

      def user_id_avatar_hash(user)
        {
          user_id: user.id,
          avatar: user.avatar ? user_avatar(user) : nil
        }
      end

      def user_avatar(user)
        thumb_url = user.avatar.attachment_url_for_api(true, :thumb)
        AttachmentDecorator.new(user.avatar).to_hash.merge(thumb_url: thumb_url)
      end
  end
end
