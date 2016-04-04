# Copyright 2014 © Freshdesk Inc. All Rights Reserved.
module Community::Moderation::CleanUp

	def empty_folder
		
		Resque.enqueue(Workers::Community::EmptyModerationTrash, 
						{
							:account_id => current_account.id, 
							:user_id => current_user.id
						})

		flash[:notice] = t('discussions.unpublished.flash.empty_folder')
		redirect_to discussions_path
	end

	def empty_topic_spam

		Resque.enqueue(Workers::Community::DeleteTopicSpam, 
						{
							:account_id => current_account.id, 
							:user_id => current_user.id,
							:klass => Post::SPAM_SCOPES_DYNAMO[:spam].to_s,
							:topic_id => params[:id]
						 })

		flash[:notice] = t('discussions.unpublished.flash.empty_topic_spam')
		respond_back
	end

	def delete_unpublished
		@topic = current_account.topics.find(params[:topic_id]) if params[:topic_id]

		@spam_post.destroy

		respond_back
	end

end