class Workers::Community::DeleteTopicSpam
	extend Resque::AroundPerform

	@queue = 'delete_topic_spam'

	class << self

		def perform(params)
			params.symbolize_keys!
			params[:klass].constantize.delete_topic_spam(params[:account_id], params[:topic_id])
		end
	end
end