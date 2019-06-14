class Community::ReportPostWorker < BaseWorker
  include Rails.application.routes.url_helpers

  sidekiq_options :queue => :report_post_worker, :retry => 0, :failures => :exhausted

    def perform(params)
      params.symbolize_keys!
      Sharding.select_shard_of(params[:account_id]) do
        account = ::Account.find params[:account_id]
        raise ActiveRecord::RecordNotFound if account.blank?
        account.make_current
        params[:klass_name] = params[:klass_name] || "Post"
        current_post = build_post(params[:id], params[:klass_name])
        analysis(params[:report_type], current_post) unless current_post.nil?
      end
    rescue => error
      Rails.logger.error "ReportPostWorker - #{Account.current} - #{error}"
      NewRelic::Agent.notice_error(error,description: "#{params}")
    ensure
      ::Account.reset_current_account
    end

    private

    def build_post(post_id, klass_name)
      klass_name.eql?("Post") ? Account.current.posts.find(post_id) : 
        ForumSpam.find_post(post_id)
    end

    def analysis(type, current_post)
      Akismetor.safe_send(type ? :submit_ham : :submit_spam, akismet_params(current_post))
    end

    def akismet_params(post)
      {
        :key => AkismetConfig::KEY,
        :comment_type => 'forum-post'
      }.merge(post_params(post)).merge(env_params)
    end

    def post_params(post)
      {
        :blog                 => post.account.full_url,
        :comment_author       => post.user.name,
        :comment_author_email => post.user.email,
        :comment_content      => post.body
      }
    end

    def env_params
      (Rails.env.production? or Rails.env.staging?) ? {} : { :is_test => 1 }
    end
end