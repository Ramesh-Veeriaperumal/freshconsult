class Workers::Community::ReportPost
  extend Resque::AroundPerform

	include Rails.application.routes.url_helpers

  @queue = 'report_post'

  class << self
	  def perform(params)
	  	current_post = build_post(params[:id])
	  	if params[:report_type]
	  		Akismetor.submit_ham(akismet_params(current_post))
	  	else
	  		Akismetor.submit_spam(akismet_params(current_post))
	  	end
	  	SpamAnalysis.push(current_post, {:user_action => params[:report_type]})
	  end

	  private

	  	def build_post(post_id)
	  		Account.current.posts.find(post_id)
	  	end

	  	def akismet_params(post)
	  		env_params = { :is_test => 1 } unless (Rails.env.production? or Rails.env.staging?)
			
			{
				:key => AkismetConfig::KEY,

				:comment_type => 'forum-post',

				:blog => post.account.full_url,
				:permalink => post.topic_url,

				:comment_author			=> post.user.name,
				:comment_author_email	=> post.user.email,
				:comment_content		=> post.body,
			}.merge(env_params || {})
		end
	end
end
