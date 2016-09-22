module Social::Twitter::TicketActions

  include Social::DynamoHelper
  include Social::Constants
  include Social::Stream::Util
  include Social::Util
  include Social::Twitter::Common

  def tweet_to_fd_item(current_feed_hash, search_type)
    feeds = build_current_interaction(current_feed_hash, search_type, true)
    fd_items = process_feeds(feeds, current_feed_hash)
  end

  def add_as_ticket(twt, twt_handle, twt_type, options={},archived_ticket = nil, user)
    tkt_hash = construct_params(twt, options)
    account  = Account.current
    
    ticket   = account.tickets.build(
      :subject    =>  Helpdesk::HTMLSanitizer.plain(tkt_hash[:body]) ,
      :twitter_id =>  user.twitter_id,
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
    ticket.requester = user
    ticket.build_archive_child(:archive_ticket_id => archived_ticket.id) if archived_ticket
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

  private

    def process_feeds(feeds, current_feed_hash)
      queue, fd_items = [[],[]]
      stream_id = current_feed_hash[:stream_id].split("_").last
      stream = Account.current.twitter_streams.find_by_id(stream_id)
      queue << current_feed_hash[:feed_id]

      while !queue.empty?
        index_to_be_deleted = nil
        current_feed_id = queue.pop
        feeds.each_with_index do |feed, index|
          if feed.feed_id == current_feed_id
            index_to_be_deleted = index
            notable = feed.convert_to_fd_item(stream, {:convert => true, :tweet =>true} )
            fd_items << notable
          else
            if feed.in_reply_to && feed.in_reply_to == current_feed_id
              queue.unshift(feed.feed_id)
            end
          end
        end
        feeds.delete_at(index_to_be_deleted) unless index_to_be_deleted.nil?
      end
      fd_items
    end

    def construct_params(twt, options)
      tweet_body = options[:tweet] ? twt[:body] : twt.text
      if options[:media_url_hash].present?
        options[:media_url_hash][:photo].present? && options[:media_url_hash][:photo].each do |photo_url_hash_key, photo_url_hash_val|
            img_element = INLINE_IMAGE_HTML_ELEMENT % photo_url_hash_val
            tweet_body = tweet_body.gsub(photo_url_hash_key, img_element)
          end
      end
      hash = {
        :body         => tweet_body.to_s.tokenize_emoji,
        :tweet_id     => options[:tweet] ? twt[:id].split(":").last.to_i : twt.id ,
        :posted_time  => options[:tweet] ? Time.at(Time.parse(twt[:postedTime]).to_i) : Time.at(twt.created_at).utc,
        :sender       => options[:tweet] ? @sender : @sender.screen_name
      }
    end
end
