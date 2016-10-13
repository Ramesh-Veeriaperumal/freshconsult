# Copyright 2014 © Freshdesk Inc. All Rights Reserved.
module Community::Moderation::CleanUp

	def empty_folder
		
		Community::EmptyModerationTrash.perform_async

		flash[:notice] = t('discussions.unpublished.flash.empty_folder')
		redirect_to discussions_path
	end

	def empty_topic_spam

		Community::ClearModerationRecords.perform_async(params[:id], "Topic")

		flash[:notice] = t('discussions.unpublished.flash.empty_topic_spam')
		respond_back
	end

	def delete_unpublished
		@topic = current_account.topics.find(params[:topic_id]) if params[:topic_id]

		@spam_post.destroy

		respond_back
	end

end