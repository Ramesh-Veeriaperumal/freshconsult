class HyperTrail::DataTransformer::PostDataTransformer < HyperTrail::DataTransformer::ActivityDataTransformer
  ACTIVITY_TYPE = 'post'.freeze
  UNIQUE_ID = 'id'.freeze

  def activity_type
    ACTIVITY_TYPE
  end

  def unique_id
    UNIQUE_ID
  end

  def transform
    loaded_posts = load_objects_from_db
    loaded_posts.each do |post|
      post_object = data_map[post.id]
      next if post_object.blank?

      post_object.valid = true
      activity = post_object.activity
      activity[:activity][:context] = fetch_decorated_properties_for_object(post)
      activity[:activity][:timestamp] = post.created_at.try(:utc)
      post_object.activity = activity
    end
  end

  private

    def load_objects_from_db
      current_account.posts.pick_published(object_ids).preload(topic: :forum)
    end

    def fetch_decorated_properties_for_object(post)
      Discussions::CommentDecorator.new(post, {}).to_timeline_hash
    end
end
