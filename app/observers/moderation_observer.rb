class ModerationObserver < ActiveRecord::Observer

	observe Post

	def after_commit(post)
	  if post.send(:transaction_include_action?, :create)
		add_to_moderation_queue(post) unless (post.published or post.user.agent? or post.import_id?)
	  end
	end

	private

		def add_to_moderation_queue(post)
			Resque.enqueue(Workers::Community::CheckForSpam, {
								:id => post.id,
								:request_params => post.request_params,
								:account_id => post.account_id
							})
		end

end
