module Community::TopicsMerge

  STATES_TO_BE_MOVED = ["followers", "user_votes"]

  def self.merge_topic(sources,target,user,source_note)
    sources.each do |source|
        aggregate_meta(target, source)
        notify(source, target, user)
        reply_to_source(source, user,source_note) unless blank_reply?(source_note)
        update_merge_activity(source, target, user)
      end
  end


  def self.aggregate_meta(target, source)
    STATES_TO_BE_MOVED.each do |state|
      source.safe_send("merge_#{state}", target)
    end
  end

  def self.notify(source, target, user)
    source.monitorships.active_monitors.includes(:portal).each do |monitor|
      next if monitor.user.email.blank? or (user.id == monitor.user_id)
      TopicMailer.send_email(:deliver_topic_merge_email, monitor.user, monitor, target, source, *monitor.sender_and_host)
    end
  end

  def self.reply_to_source(source, user, post)
    post = source.posts.build(
      :body_html => post,
      :forum_id => source.forum_id,
      :user_id => user.id)
    post.account_id = Account.current.id
    post.save!
  end

  def self.update_merge_activity(source, target, user)
    source.activities.create(
      :user_id => user.id,
      :description => 'activities.forums.topic_merge.long',
      :short_descr => 'activities.forums.topic_merge.short',
      :activity_data => {
        :path => "/discussions/topics/#{source.id}",
        :url_params => {
          :topic_id => source.id,
          :path_generator => 'discussions_topic_path'
        },
        :title => h(source.title),
        'eval_args' => { 'target_topic_path' => ['target_topic_path', target.id] }
      }
    )
  end


  def self.blank_reply?(note)
    return true if note.blank?
    ['&nbsp;', '<br>', '<br />', '<p>', '</p>', '<div dir="ltr">', '</div>'].each { |str| note.gsub!(str, '') }
    note.blank?
  end


end