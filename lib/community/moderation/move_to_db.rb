# Copyright 2014 © Freshdesk Inc. All Rights Reserved.
module Community::Moderation::MoveToDB

	include CloudFilesHelper
	
	REPORT_HAM = true

	def approve
		begin
			topic_post_saved = Topic.transaction do
				topic_saved = find_or_approve_topic
				approve_post if !@spam_post.topic_id.nil? or topic_saved
			end
			@spam_post.destroy if topic_post_saved
			report_post(@published_post, REPORT_HAM) if @spam_post.spam?
			respond_back
		rescue ActiveRecord::RecordInvalid => e
			invalid_topic_message(e)
		end
	end

	private

		def find_or_approve_topic
			if @spam_post.topic_id.nil?
				approve_topic
			else
				@topic = current_account.topics.find(@spam_post.topic_id)
			end
		end

		def approve_topic
			forum = current_account.forums.find(@spam_post.forum_id)
			@topic = forum.topics.new(topic_params)
			@topic.approve!
		end

		def approve_post
			@published_post = current_account.posts.new(post_params)
			@published_post.topic = @topic
			move_attachments(@spam_post.attachments, @published_post) if @spam_post.attachments.present?
			build_cloud_files_attachments(@published_post, JSON.parse(@spam_post.cloud_file_attachments))
			@published_post.approve!
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