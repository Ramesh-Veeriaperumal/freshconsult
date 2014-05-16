class Social::Twitter::DirectMessage

  #TODO @ARV : reorg this similar to Twitter:Feed where process is a class function and we create objects of type DirectMessage

  attr_accessor :twitter, :twt_handle
  include Social::Twitter::Util
  include Social::Dynamo::Twitter

  def initialize(twt_handle, options = {})
    wrapper         = TwitterWrapper.new twt_handle
    self.twitter    = wrapper.get_twitter
    self.twt_handle = twt_handle
  end

  def process
    tweets = twt_handle.last_dm_id.blank? ? twitter.direct_messages : twitter.direct_messages({:since_id => twt_handle.last_dm_id})
    last_tweet_id = tweets[0].id unless tweets.blank?
    tweets.each do |twt|
      create_fd_item(twt, twt_handle)
    end
    twt_handle.update_attribute(:last_dm_id, last_tweet_id) unless last_tweet_id.blank?
  end


  private

  def create_fd_item(twt, twt_handle)
    @sender = twt.sender
    account = twt_handle.account
    user    = set_user(@sender)
    previous_ticket = user.tickets.twitter_dm_tickets.newest(1).first
    unless previous_ticket.blank?
      if (!previous_ticket.notes.blank? && !previous_ticket.notes.latest_twitter_comment.blank?)
        last_reply =  previous_ticket.notes.latest_twitter_comment.first
      else
        last_reply =  previous_ticket
      end
    end
    action_data = extract_action_data(twt_handle)
    default_stream = twt_handle.default_stream
    action_data.merge!(:stream_id => default_stream.id) if default_stream
    if last_reply && (Time.zone.now < (last_reply.created_at + twt_handle.dm_thread_time.seconds))
      add_as_note(twt, twt_handle, :dm, previous_ticket, user,  action_data)
    else
      add_as_ticket(twt, twt_handle, :dm, action_data)
    end
    update_dynamo_for_dm(account, twt, default_stream) if default_stream # Make dynamo call last after note or ticket creation
    User.reset_current_user
  end

  def extract_action_data(twt_handle)
    action_data = {}
    dm_stream   = twt_handle.dm_stream
    if dm_stream
      dm_tkt_rules = dm_stream.ticket_rules
      action_data  = dm_tkt_rules.first.action_data unless dm_tkt_rules.empty?
    end
    action_data
  end

  def update_dynamo_for_dm(account, twt, default_stream)
    stream_id = "#{account.id}_#{default_stream.id}"
    params = {
      :id        => twt.attrs[:id_str],
      :user_id   => twt.attrs[:sender_id_str],
      :body      => twt.attrs[:text],
      :posted_at => twt.attrs[:created_at]
    }
    update_dm(stream_id, params)
  end

  def set_user(sender)
    user = get_twitter_user(sender.screen_name, sender.profile_image_url)
    user.make_current
  end

end
