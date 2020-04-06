class Topic < ActiveRecord::Base

	def merge_followers(target)
		self.monitorships.active_monitors.includes([:user]).find_each do |mon|
			new_mon = find_or_initialize_monitorship(mon.user_id, target)
			new_mon.active = true
			new_mon.portal ||= possible_portal(target)
			new_mon.save
		end
	end

	def merge_user_votes(target)
		self.votes.includes([:user]).find_each do |source_vote|
			new_vote = find_or_initialize_vote(source_vote.user_id, target)
			new_vote.vote = source_vote.vote
			new_vote.account_id = source_vote.account_id
			new_vote.created_at ||= source_vote.created_at
			new_vote.save
		end
	end

	private

		def possible_portal(target)
			(target.forum.forum_category.portals || []).first
		end

		def find_or_initialize_monitorship(user_id, topic)
			Monitorship.find_or_initialize_by_user_id_and_monitorable_id_and_monitorable_type(user_id, topic.id, "Topic")
		end

		def find_or_initialize_vote(user_id, topic)
			Vote.find_or_initialize_by_user_id_and_voteable_id_and_voteable_type(user_id, topic.id, "Topic")
		end

end