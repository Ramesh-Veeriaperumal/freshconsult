module Social::Twitter::Util

  include Social::Twitter::Constants

  def add_as_ticket(twt, twt_handle, twt_type, options={})
    tkt_hash = construct_params(twt, options)
    account  = Account.current
    ticket   = account.tickets.build(
      :subject    =>  Helpdesk::HTMLSanitizer.plain(tkt_hash[:body]) ,
      :twitter_id =>  tkt_hash[:sender] ,
      :product_id => options[:product_id] || twt_handle.product_id,
      :group_id   => options[:group_id] || ( twt_handle.product ? twt_handle.product.primary_email_config.group_id : nil),
      :source     => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:twitter],
      :created_at =>  tkt_hash[:posted_time] ,
      :tweet_attributes => {
        :tweet_id           => tkt_hash[:tweet_id] ,
        :tweet_type         => twt_type.to_s,
        :twitter_handle_id  => twt_handle.id,
        :stream_id          => options[:stream_id]
      },
      :ticket_body_attributes => {
        :description_html => tkt_hash[:body]
      }
    )

    if ticket.save_ticket
      Rails.logger.debug "This ticket has been saved - #{tkt_hash[:tweet_id]}"
    else
      NewRelic::Agent.notice_error("Error in converting a tweet to ticket", :custom_params =>
                                   {:error_params => ticket.errors.to_json})
      Rails.logger.debug "error while saving the ticket - #{tkt_hash[:tweet_id]} :: #{ticket.errors.to_json}"
      ticket = nil
    end
    return ticket
  end

  def add_as_note(twt, twt_handle, twt_type, ticket, user, options={})
    note_hash = construct_params(twt, options)

    note = ticket.notes.build(
      :note_body_attributes => {
        :body_html => note_hash[:body]
      },
      :incoming   => true,
      :source     => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:twitter],
      :account_id => twt_handle.account_id,
      :user_id    => user.id,
      :created_at => note_hash[:posted_time],
      :tweet_attributes => {
        :tweet_id           => note_hash[:tweet_id] ,
        :tweet_type         => twt_type.to_s,
        :twitter_handle_id  => twt_handle.id,
        :stream_id          => options[:stream_id]
      }
    )

    if note.save_note
      Rails.logger.debug "This note has been added - #{note_hash[:tweet_id]}"
    else
      NewRelic::Agent.notice_error("Error in converting a tweet to ticket", :custom_params =>
                                   {:error_params => note.errors.to_json})
      Rails.logger.debug "error while saving the note - #{note_hash[:tweet_id]} :: #{note.errors.to_json}"
      note = nil
    end
    return note
  end

  def get_twitter_user(screen_name, profile_image_url=nil)
    account = Account.current
    user = account.all_users.find_by_twitter_id(screen_name)
    unless user
      user = account.contacts.new
      user.signup!({
                     :user => {
                       :twitter_id      => screen_name,
                       :name            => screen_name,
                       :active          => true,
                       :helpdesk_agent  => false
                     }
      })
    end
    if user.avatar.nil? && !profile_image_url.nil?
      args = {
        :account_id       => account.id,
        :twitter_user_id  => user.id,
        :prof_img_url     => profile_image_url
      }
      Resque.enqueue(Social::Workers::Twitter::UploadAvatar, args)
    end
    user
  end

  def construct_params(twt, options)
    hash = {
      :body         => options[:tweet] ? twt[:body] : twt.text,
      :tweet_id     => options[:tweet] ? twt[:id].split(":").last.to_i : twt.id ,
      :posted_time  => options[:tweet] ? Time.at(Time.parse(twt[:postedTime]).to_i) : Time.at(twt.created_at).utc,
      :sender       => options[:tweet] ? @sender : @sender.screen_name
    }
  end

  def user_recent_tickets(screen_name)
    requester = current_account.users.find_by_twitter_id(screen_name, :select => "id")
    tickets   = current_account.tickets.requester_active(requester).visible.newest(3).find(:all) if requester
  end

  def process_twitter_entities(twitter_entities)
    return [] if twitter_entities.blank?
    return_symbolized_keys!(twitter_entities)
    user_mentions_hash = twitter_entities[:user_mentions]
    mentions = user_mentions_hash.map { |mention| mention[:screen_name] }
  end

  def return_symbolized_keys!(h)
    h.symbolize_keys!
    h.each do |k, v|
      v.each do |k1, v1|
        k1.symbolize_keys! if k1.is_a? Hash
      end
    end
  end

  # By default twitter gives normal img. Removing the "_normal" gives the original image
  def process_img_url(img_url)
    original_img_url = img_url.gsub("_normal", "")
  end

end
