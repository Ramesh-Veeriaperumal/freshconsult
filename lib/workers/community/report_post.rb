class Workers::Community::ReportPost
  extend Resque::AroundPerform

	include ActionController::UrlWriter

  @queue = 'report_post'

  class << self
	  def perform(params)
	  	if params[:report_type]
	  		Akismetor.submit_ham(akismet_params(build_post(params[:id])))
	  	else
	  		Akismetor.submit_spam(akismet_params(build_post(params[:id])))
	  	end
	  end

	  private

	  	def build_post(post_id)
	  		Account.current.posts.find(post_id)
	  	end

	  	def akismet_params(post)
			{
				:key => AkismetConfig::KEY,

				:blog => post.account.full_url,
				:permalink => post.topic_url,

				:comment_author			=> post.user.name,
				:comment_author_email	=> post.user.email,
				:comment_content		=> post.body,
			}

		end
	end
end
