class Workers::Community::ReportPost
  extend Resque::AroundPerform

	include Rails.application.routes.url_helpers

  @queue = 'report_post'

  class << self
  	
	  def perform(params)
	  	params[:klass_name] = params[:klass_name] || "Post"
	  	current_post = build_post(params[:id], params[:klass_name])
	  	analysis(params[:report_type], current_post) unless current_post.nil?
	  end

	  private

		def build_post(post_id, klass_name)
			klass_name.eql?("Post") ? Account.current.posts.find(post_id) : 
					ForumSpam.find(:account_id => Account.current.id, :timestamp => post_id)
		end

		def analysis(type, current_post)
			Akismetor.send(type ? :submit_ham : :submit_spam, akismet_params(current_post))
			SpamAnalysis.push(current_post, {:user_action => type})
		end

		def akismet_params(post)
			{
				:key => AkismetConfig::KEY,
				:comment_type => 'forum-post'
			}.merge(post_params(post)).merge(env_params)
		end

		def post_params(post)
			{
				:blog => post.account.full_url,
				:comment_author			=> post.user.name,
				:comment_author_email	=> post.user.email,
				:comment_content		=> post.body
			}
		end

		def env_params
			(Rails.env.production? or Rails.env.staging?) ? {} : { :is_test => 1 }
		end
	end
end
