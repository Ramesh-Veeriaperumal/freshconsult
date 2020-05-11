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
			Monitorship.where(user_id: user_id, monitorable_id: topic.id, monitorable_type: 'Topic').first_or_initialize
		end

		def find_or_initialize_vote(user_id, topic)
			Vote.where(user_id: user_id, voteable_id: topic.id, voteable_type: 'Topic').first_or_initialize
		end

end