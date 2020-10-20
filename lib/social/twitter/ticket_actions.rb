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
      :twitter_id =>  user.twitter_id,
      :product_id => options[:product_id] || twt_handle.product_id,
      :group_id   => options[:group_id] || ( twt_handle.product ? twt_handle.product.primary_email_config.group_id : nil),
      :source     => Helpdesk::Source::TWITTER,
      :created_at =>  tkt_hash[:posted_time] ,
      :tweet_attributes => {
        :tweet_id           => tkt_hash[:tweet_id] ,
        :tweet_type         => twt_type.to_s,
        :twitter_handle_id  => twt_handle.id,
        :stream_id          => options[:stream_id]
      }
    )
    body_content = construct_item_body(account, ticket, twt, options)
    ticket.subject = Helpdesk::HTMLSanitizer.plain(tokenize(body_content))
    ticket.ticket_body_attributes = {
      :description_html => body_content
    }
    if options[:from_social_tab] == true
      ticket.activity_type = {
        type: TWITTER_FEED_TICKET
      }
    end
    ticket.requester = user
    ticket.build_archive_child(:archive_ticket_id => archived_ticket.id) if archived_ticket
    if ticket.save_ticket
      Rails.logger.debug "This ticket has been saved - #{tkt_hash[:tweet_id]}, user : #{user.id}"
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
    account  = Account.current

    note = ticket.notes.build(
      :incoming   => true,
      :source     => Helpdesk::Source::TWITTER,
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

    note.note_body_attributes = {
      :body_html => construct_item_body(account, note, twt, options)
    }

    note.activity_type = { type: TWITTER_FEED_NOTE } if options[:from_social_tab] == true

    if note.save_note
      Rails.logger.debug "This note has been added - #{note_hash[:tweet_id]}, user : #{user.id}"
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
            params_hash = {:convert => true, :tweet =>true}
            params_hash.merge!(from_social_tab: true)
            notable = feed.convert_to_fd_item(stream, params_hash)
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
      hash = {
        :tweet_id     => options[:tweet] ? twt[:id].split(":").last.to_i : twt.id ,
        :posted_time  => options[:tweet] ? Time.at(Time.parse(twt[:postedTime]).to_i) : Time.at(twt.created_at).utc,
        :sender       => options[:tweet] ? @sender : @sender.screen_name
      }
    end

    def construct_item_body(account, item, twt, options)
      media_url_hash = fetch_media_url(account, item, twt, options)
      tweet_body = options[:tweet] ? tweet_body(twt) : twt.text
      if media_url_hash.present?
        img_content = ''
        media_url_hash[:photo].each do |photo_url_hash_key, photo_url_hash_val|
          img_content << INLINE_IMAGE_HTML_ELEMENT % { url: photo_url_hash_val, data_test_url: photo_url_hash_key }
        end
        img_element = TWITTER_IMAGES % { img_content: img_content }
        tweet_body = tweet_body.gsub(media_url_hash[:twitter_url], img_element)
      end
      tweet_body
    end
end
