module Gamification
	module Quests
		class ProcessPostQuests 
			extend Resque::AroundPerform
			@queue = "gamificationQueue"

			def self.perform(args)
				args.symbolize_keys!
				id, account_id = args[:id], args[:account_id]
				post = Post.find_by_id_and_account_id(id, account_id)
				evaluate_post_quests(post) unless post.blank?
			end

			def self.evaluate_post_quests(post)
				return if (post.user.customer? or post.user_id == post.topic.user_id)
				RAILS_DEFAULT_LOGGER.debug %(INSIDE evaluate_post_quests)
				post.user.available_quests.answer_forum_quests.each do |quest|
					is_a_match = quest.matches(post)
					if is_a_match and evaluate_query(quest,post)
						quest.award!(post.user)
					end
				end
			end

			def self.evaluate_query(quest, post, end_time=Time.zone.now)
				conditions = quest.filter_query
				f_criteria = quest.time_condition(end_time)
				conditions[0] = conditions.empty? ? f_criteria : (conditions[0] + ' and ' + f_criteria)

				created_posts_in_time = quest_scoper(post.account, post.user).count(
					'posts.id', :conditions => conditions)

				quest_achieved = created_posts_in_time >= quest.quest_data[0][:value].to_i
			end

			def self.quest_scoper(account, user)
				account.posts.by_user(user)
			end

		end
	end
end