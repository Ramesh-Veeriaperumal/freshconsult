module Social::Dynamo::Interaction

  include Social::Constants
  include Social::Twitter::Constants
  include Gnip::Constants

  TABLE = "interactions"
  SCHEMA = TABLES[TABLE][:schema]

  def insert_user_interactions(posted_time, stream_id, parent_feed_id_hash, params)
    key = "#{stream_id}"
    range = params[:in_reply_to_user_id]
    feed_id = params[:id]
    times = [posted_time, posted_time + 7.days]
    times.each do |time|
      table_name = Social::DynamoHelper.select_table(TABLE, time)
      item_hash = interactions_hash(key, "user:#{range}", feed_id ,"")
      if Social::DynamoHelper.table_validity(TABLE, table_name, Time.now)
        Social::DynamoHelper.insert(table_name, item_hash, SCHEMA)
        update_current_interaction_list(table_name, key, parent_feed_id_hash["#{time}"], feed_id, SCHEMA)
      end
    end
  end

  def update_current_interaction_list(table_name, key, parent_feed_id, feed_id, schema)
    item_hash = interactions_hash(key, "feed:#{parent_feed_id}", feed_id, "")
    Social::DynamoHelper.update(table_name, item_hash, schema)
  end

  def insert_user_dm_interactions(posted_time, stream_id, user_id, dm_hash)
    item_hash = interactions_hash(stream_id, "user:#{user_id}", "", dm_hash)
    times = [posted_time, posted_time + 7.days]
    times.each do |time|
      table_name = Social::DynamoHelper.select_table(TABLE, time)
      if Social::DynamoHelper.table_validity(TABLE, table_name, Time.now)
        Social::DynamoHelper.insert(table_name, item_hash, SCHEMA)
      end
    end
  end

  def interactions_hash(hash, range, feed_id, dm)
    item = {
      "stream_id" => {
        :s => "#{hash}"
      },
      "object_id" => {
        :s => "#{range}"
      }
    }
    unless feed_id.blank?
      item.merge!("feed_ids" => { :ss => [feed_id.to_s]})
    end

    unless dm.blank?
      item.merge!("dm" => { :ss => [dm.to_json]})
    end
    return item
  end

end
