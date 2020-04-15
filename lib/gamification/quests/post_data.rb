module Gamification
	module Quests
		class PostData

			def initialize(args)
				args.symbolize_keys!
				@post = Account.current.posts.find(args[:id])
			end

			def evaluate_post_quests
				return if @post.blank? || (@post.user.customer? or @post.user_id == @post.topic.user_id)
				Rails.logger.debug %(INSIDE evaluate_post_quests)
				@post.user.available_quests.answer_forum_quests.each do |quest|
					is_a_match = quest.matches(@post)
					if is_a_match and evaluate_query(quest,@post)
						quest.award!(@post.user)
					end
				end
			end

			def evaluate_query(quest, post, end_time=Time.zone.now)
				conditions = quest.filter_query
				f_criteria = quest.time_condition(end_time)
				conditions[0] = conditions.empty? ? f_criteria : (conditions[0] + ' and ' + f_criteria)

				created_posts_in_time = quest_scoper(post.account, post.user).where(conditions).count('posts.id')

				quest_achieved = created_posts_in_time >= quest.quest_data[0][:value].to_i
			end

			def quest_scoper(account, user)
				account.posts.by_user(user)
			end
		end
	end
end