class HyperTrail::DataTransformer::PostDataTransformer < HyperTrail::DataTransformer::ActivityDataTransformer
  ACTIVITY_TYPE = 'post'.freeze

  def activity_type
    ACTIVITY_TYPE
  end

  def collection_id
    :id
  end

  def load_objects(ids)
    loaded_posts = current_account.posts.pick_published(ids).preload(topic: :forum)
    loaded_posts_map = Hash[*loaded_posts.map { |post| [post.id, post] }.flatten]
    loaded_posts_map
  end

  def fetch_decorated_properties_for_object(post)
    Discussions::CommentDecorator.new(post, {}).to_timeline_hash
  end
end
