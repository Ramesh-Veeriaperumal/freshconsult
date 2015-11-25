module DiscussionConstants
  # ControllerConstants
  CATEGORY_FIELDS = ['name', 'description'].freeze
  FORUM_ARRAY_FIELDS = ['company_ids'].freeze
  CREATE_FORUM_FIELDS = %w(name description forum_type forum_visibility company_ids).freeze | FORUM_ARRAY_FIELDS.map { |x| Hash[x, [nil]] }
  UPDATE_FORUM_FIELDS = CREATE_FORUM_FIELDS << 'forum_category_id'
  UPDATE_TOPIC_FIELDS = { all: %w(title message_html stamp_type), edit_topic: ['sticky', 'locked'], manage_forums: ['forum_id'] }.freeze
  CREATE_TOPIC_FIELDS = { all: %w(title message_html stamp_type), edit_topic: ['sticky', 'locked'] }.freeze
  COMMENT_FIELDS = %w(body_html answer).freeze
  IS_FOLLOWING_FIELDS = ['user_id', 'id'].freeze
  FOLLOWED_BY_FIELDS = FOLLOW_FIELDS = UNFOLLOW_FIELDS = ['user_id'].freeze

  # ValidationConstants
  FORUM_VISIBILITY_KEYS_BY_TOKEN = Forum::VISIBILITY_KEYS_BY_TOKEN
  FORUM_VISIBILITY = Forum::VISIBILITY_KEYS_BY_TOKEN.values
  FORUM_TYPE = Forum::TYPE_KEYS_BY_TOKEN.values
  LOAD_OBJECT_EXCEPT = [:followed_by, :is_following, :category_forums, :forum_topics, :topic_posts].freeze

  CATEGORY_ATTRIBUTES_TO_BE_STRIPPED = %w(name).freeze
  FORUM_ATTRIBUTES_TO_BE_STRIPPED = %w(name description).freeze
  TOPIC_ATTRIBUTES_TO_BE_STRIPPED = %w(title).freeze
end.freeze
