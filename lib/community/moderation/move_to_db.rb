# Copyright 2014 © Freshdesk Inc. All Rights Reserved.
module Community::Moderation::MoveToDB

	include CloudFilesHelper

	def approve
		begin
			@spam_post.destroy if save_object
			report_post(@published_post, Post::REPORT[:ham]) if @spam_post.spam?
			respond_back
		rescue ActiveRecord::RecordInvalid => e
			invalid_topic_message(e)
		end
	end

	private
		def save_object
			find_or_initialize_topic
			initialize_post
			@spam_post.topic_id.nil? ? @topic.approve! : @published_post.approve!
		end
		
		def find_or_initialize_topic
			if @spam_post.topic_id.nil?
				initialize_topic
			else
				@topic = current_account.topics.find(@spam_post.topic_id)
			end
		end

		def initialize_topic
			forum = current_account.forums.find(@spam_post.forum_id)
			@topic = forum.topics.new(topic_params)
		end

		def initialize_post
			@published_post = @topic.posts.build(post_params)
			@published_post.topic = @topic
			@published_post.published = true
			move_attachments(@spam_post.attachments, @published_post) if @spam_post.attachments.present?
			build_cloud_files_attachments(@published_post, JSON.parse(@spam_post.cloud_file_attachments))
		end

		def topic_params
			{
				:title => @spam_post.title,
			}.merge(common_attributes || {})
		end

		def post_params
			{
				:body_html => @spam_post.body_html,
				:portal => (@spam_post.attributes.has_key?('portal') ? @spam_post.portal : nil)
			}.merge(common_attributes || {})
		end

		def common_attributes
			{
				:user_id => @spam_post.user_id,
				:created_at => Time.at(@spam_post.timestamp).utc,
				:updated_at => Time.at(@spam_post.timestamp).utc
			}
		end

		def invalid_topic_message(e)
			NewRelic::Agent.notice_error(e)
			Rails.logger.error("Error while saving post! Post invalid")
			respond_to do |format|
				format.js { render "invalid_topic.rjs" }
			end
		end

end