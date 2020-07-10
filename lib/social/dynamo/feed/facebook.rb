class Social::Dynamo::Feed::Facebook < Social::Dynamo::Feed::Base
  
  def update_parent_comment_in_dynamo(hash, parent_comment, posted_time, source)
    execute_on_table(posted_time) do |table_name, time|
      item_hash = feeds_hash(hash, parent_comment, "", 0, 1, "", source)
      comment_count = {"comments_count" => {:n => "1"}}
      item_hash.merge!(comment_count) if comment_count.present?
      Social::DynamoHelper.update(table_name, item_hash, SCHEMA)
    end
  end
  
  def update_likes(hash_key, feed_id, likes)
    attributes = {
      "likes" => "#{likes}"
    }
    item_hash = feeds_hash(hash_key, feed_id, "", 0, 0, attributes, SOURCE[:facebook])
    
    dynamo_keys =  {
      :stream_id  => hash_key.split("_").last,
      :account_id => hash_key.split("_").first
    }
    
    execute_on_table(Time.now.utc) do |table_name, time|
      Social::DynamoHelper.update(table_name, item_hash, SCHEMA) if has_parent_feed?(time, dynamo_keys, feed_id)
    end
  end

  def update_fd_links(table_name, parent_feed_id, hash)
    parent_interaction = Social::Dynamo::Interaction.new.get_feed_interaction(hash, parent_feed_id)
    if parent_interaction && parent_interaction.present?
      interactions = parent_interaction['feed_ids']
      interactions.each do |interaction|
        attributes = fd_attributes(interaction)
        item_hash  = feeds_hash(hash, interaction, "", 0, 0, attributes, SOURCE[:facebook])
        if Social::DynamoHelper.get_item(table_name, hash, interaction, SCHEMA, [RANGE_KEY])[:item]
          Social::DynamoHelper.update(table_name, item_hash, SCHEMA, ['fd_link'])
        end
      end
    end
  end

  private
  def fetch_parent_data(table_name, hash, feed_obj)
    in_conversation = 0
    koala_feed      = feed_obj.koala_feed
    in_reply_to     = koala_feed.in_reply_to
    feed_id         = koala_feed.feed_id
    parent_feed_id  = "#{feed_id}"
    
    if in_reply_to
      attributes_to_get = [RANGE_KEY, "parent_feed_id", "in_conversation", "source", "type"]
      parent_attributes = get_parent_data(table_name, hash, in_reply_to, attributes_to_get)
      
      if parent_attributes.present?
        parent_feed_id = parent_attributes[:parent_feed_id]
        if feed_obj.instance_of?(Facebook::Core::Comment)
          in_conv        = (parent_attributes[:parent_conversation] == 0) ? 1 : 0
          comment_count  = {"comments_count" => {:n => "1"}}
          if in_conv == 1 or comment_count.present?
            item_hash = feeds_hash(hash, in_reply_to, "", 0, 1, "", parent_attributes[:source])
            item_hash.merge!(comment_count) if comment_count.present?
            Social::DynamoHelper.update(table_name, item_hash, SCHEMA)
          end
        end
      end
      
    end
    [parent_feed_id, in_conversation, feed_id]
  end
  
  def fd_attributes(interaction)
    attributes = ""
    fd_object  = Account.current.facebook_posts.find_by_post_id(interaction)
    if fd_object
      user       = fd_object.is_ticket? ? fd_object.postable.requester : fd_object.postable.user 
      attributes = fd_info(fd_object.try(:postable), user)
    end
    attributes
  end
  
end
