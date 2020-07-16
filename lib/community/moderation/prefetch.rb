# Copyright 2014 © Freshdesk Inc. All Rights Reserved.
module Community::Moderation::Prefetch

	def fetch_associations
		fetch_topics(collect(:topic_id))
		fetch_forums(map('forum_id'))
		fetch_users(collect(:user_id))
	end

	def fetch_topics(topic_ids)
		topics = current_account.topics.find(:all, :conditions => {:id => topic_ids}, :include => :forum )
		@fetched_topics = Hash[*topics.map { |t| [t.id, t] }.flatten]
	end

	def fetch_users(user_ids)
		users = current_account.all_users.find(:all, :conditions => {:id => user_ids})
		@fetched_users = Hash[*users.map { |u| [u.id, u] }.flatten]
	end

	def fetch_forums(forum_ids)
		forums = current_account.forums.find(:all, :conditions => {:id => forum_ids}, :include => :forum_category)
		@fetched_forums = Hash[*forums.map { |f| [f.id, f] }.flatten]
	end

	def collect(att)
		@spam_posts.collect(&att).uniq.compact
	end

	def map(att)
		@spam_posts.map{ |s| s[att] unless s[att].nil?}.uniq.compact
	end
end
