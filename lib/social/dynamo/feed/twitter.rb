class Social::Dynamo::Feed::Twitter < Social::Dynamo::Feed::Base
  
  include Gnip::Constants
  
  def insert_agent_reply(stream_id, reply_params, parent_data, note, table_name)
    posted_time = Time.parse(reply_params[:posted_at])
    reply_hash  = construct_agent_reply_hash(reply_params, posted_time, parent_data[:feed_id], note)
    hash        = stream_id
    range       = reply_params[:id]

    item_hash = feeds_hash(hash, range, reply_hash[:data], 0, parent_data[:in_conversation],
                                reply_hash[:fd_attributes], reply_params[:source])
    Social::DynamoHelper.insert(table_name, item_hash, SCHEMA)
  end
  
  def update_feed_reply(stream_id, posted_time, reply_params, note)
    parent_feed_id_hash = parent_data =  {}
    in_reply_to = reply_params[:in_reply_to_id]
    
    execute_on_table(posted_time) do |table_name, time|
      item_hash  = feeds_hash(stream_id, in_reply_to, "", 1, 1, "", reply_params[:source])
      response   = Social::DynamoHelper.update(table_name, item_hash, SCHEMA)

      if response[:attributes]["parent_feed_id"]
        parent_feed_id = response[:attributes]["parent_feed_id"][:ss].first
        parent_feed_id_hash.merge!("#{time}" => "#{parent_feed_id}" )
        parent_data = {
          :feed_id => parent_feed_id,
          :in_conversation => 1
        }
        insert_agent_reply(stream_id, reply_params, parent_data, note, table_name)
      end
    end
    parent_feed_id_hash
  end
  
  private
  def fetch_parent_data(table_name, hash, feed_obj)
    in_conversation = 0
    in_reply_to     = feed_obj.in_reply_to
    feed_id         = feed_obj.feed_id
    parent_feed_id  = "#{feed_id}"
    
    if in_reply_to
      attributes_to_get = [RANGE_KEY, "parent_feed_id", "in_conversation", "source"]
      parent_attributes = get_parent_data(table_name, hash, in_reply_to, attributes_to_get)
      parent_feed_id    = parent_attributes[:parent_feed_id] if parent_attributes.present?
      if parent_attributes.present? and parent_attributes[:parent_conversation] == 0
        item_hash = feeds_hash(hash, in_reply_to, "", 0, 1, "", parent_attributes[:source])
        Social::DynamoHelper.update(table_name, item_hash, SCHEMA)
      end
    end
    [parent_feed_id, in_conversation, feed_id]
  end
  
  def construct_agent_reply_hash(reply_params, posted_time, parent_feed_id, note)
    { 
      :data => twitter_tweet_hash(reply_params, Time.parse(reply_params[:posted_at]).utc, true),
      :fd_attributes => {
          :posted_time    => "#{(posted_time.to_f * 1000).to_i}",
          :replied_by     => reply_params[:agent_name] ,
          :fd_link        => helpdesk_ticket_link(note),
          :parent_feed_id => parent_feed_id
      }   
    }
  end
  
  def twitter_tweet_hash(reply_params, dynamo_posted_time, reply = false)
    data = {
      "body"  => reply_params[:body],
      "actor" => {
        "displayName"       => reply_params[:user][:name],
        "preferredUsername" => reply_params[:user][:screen_name] ,
        "image"             => reply_params[:user][:image],
        "id"                => (reply ? reply_params[:in_reply_to_user_id] : reply_params[:user][:id])
      },
      "id"         => reply_params[:id],
      "postedTime" => dynamo_posted_time.strftime("%FT%T.000Z"),
      "inReplyTo"  => {
        "link" => reply_params[:in_reply_to_id]
      },
      "twitter_entities" => {
        "user_mentions" => reply_params[:user_mentions]
      }
    }
  end
  
end
