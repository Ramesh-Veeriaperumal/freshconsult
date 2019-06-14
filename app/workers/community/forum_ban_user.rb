class Community::ForumBanUser < BaseWorker

  include SpamAttachmentMethods
  include SpamPostMethods

  sidekiq_options :queue => :forum_ban_user, :retry => 0, :failures => :exhausted

  def perform(params)
    account = Account.current
    params.deep_symbolize_keys!
    spam_user = account.all_users.find_by_id(params[:spam_user_id])
    return if spam_user.nil?

    # posts in Dynamo
    ban_posts_dynamo(account.id, spam_user)

    # published posts
    ban_published_posts(spam_user)
  rescue => e
    Rails.logger.debug "Exception while performing ban user,\n#{e.message}\n#{e.backtrace.join("\n\t")}"
    NewRelic::Agent.notice_error(e, description: 'Exception while performing ban user')
  end

  private

  def ban_posts_dynamo(account_id, spam_user)
    results = ForumUnpublished.by_user(spam_user.id, next_user_timestamp(spam_user))
    while(results.present?)
      convert_to_spam(results)
      last = results.last.user_timestamp
      results = ForumUnpublished.by_user(spam_user.id, last)
    end 
  end

  def ban_published_posts(spam_user)
    spam_user.posts.each do |post|
      ban_post(post) if post.present? and post.topic.present?
    end
  end

  def convert_to_spam(posts)
    posts.each do |p|
      p.destroy if build_spam_post(p.attributes)
      report_post(@post, Post::REPORT[:spam])
    end
  end

  def build_spam_post(params)
    @post = ForumSpam.build(params)
    @post.save
  end

  def next_user_timestamp(spam_user)
    spam_user.id * (10 ** 17) + (Time.now - ForumSpam::UPTO).utc.to_f * (10 ** 7)
  end

  def ban_post(post)
    if create_dynamo_post(post, {:spam => true})
      post.original_post? ? post.topic.destroy : post.destroy 
    end
  end

end