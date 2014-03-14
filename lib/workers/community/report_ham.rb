class Workers::Community::ReportHam
  extend Resque::AroundPerform

	include ActionController::UrlWriter

  @queue = 'report_ham'

  class << self
	  def perform(params)
	  	Akismetor.submit_ham(akismet_params(build_post(params[:id])))
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
