class Workers::Community::CheckForSpam
  extend Resque::AroundPerform

	include ActionController::UrlWriter

  @queue = 'check_for_spam'

  class << self
	  def perform(params)
	  	params.symbolize_keys!
	  	post = build_post(params[:id])
	  	process(post, params[:request_params])
	  end

	  private

	  	def build_post(post_id)
	  		Account.current.posts.find(post_id)
	  	end

	  	def process(post, request_params)
	  		post.spam = is_spam?(post, request_params)
	  		post.published = !post.spam?

	  		post.save
	  	end

	  	def is_spam?(post, request_params)
	  		Akismetor.spam?(akismet_params(post, request_params))
	  	end

	  	def akismet_params(post, request_params)
			{
				:key => AkismetConfig::KEY,

				:blog => post.account.full_url,
				:permalink => post.topic_url,

				:comment_author			=> post.user.name,
				:comment_author_email	=> post.user.email,
				:comment_content		=> post.body,
			}.merge((request_params || {}).symbolize_keys)

		end
	end
end
