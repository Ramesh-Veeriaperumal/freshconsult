module DiscussionConstants
  # ControllerConstants
  CATEGORY_FIELDS = ['name', 'description']
  FORUM_FIELDS = ['name', 'description', 'forum_category_id', 'forum_type', 'forum_visibility', 'company_ids', 'company_ids' => []]
  UPDATE_TOPIC_FIELDS = { all: %w(title message_html stamp_type), edit_topic: ['sticky', 'locked'], manage_forums: ['forum_id'] }
  CREATE_TOPIC_FIELDS = { all: %w(title message_html stamp_type forum_id), edit_topic: ['sticky', 'locked'] }
  UPDATE_POST_FIELDS = ['body_html', 'answer']
  CREATE_POST_FIELDS = %w(body_html answer topic_id)
  IS_FOLLOWING_FIELDS = ['user_id', 'id']
  FOLLOWED_BY_FIELDS = ['user_id']

  # ValidationConstants
  FORUM_VISIBILITY_KEYS_BY_TOKEN = Forum::VISIBILITY_KEYS_BY_TOKEN
  FORUM_VISIBILITY = Forum::VISIBILITY_KEYS_BY_TOKEN.values | Forum::VISIBILITY_KEYS_BY_TOKEN.values.map(&:to_s)
  FORUM_TYPE = Forum::TYPE_KEYS_BY_TOKEN.values | Forum::TYPE_KEYS_BY_TOKEN.values.map(&:to_s)
  LOAD_OBJECT_EXCEPT = [:followed_by, :is_following, :category_forums, :forum_topics, :topic_posts]

  CATEGORY_FIELDS_TO_BE_STRIPPED = %w(name)
  FORUM_FIELDS_TO_BE_STRIPPED = %w(name)
  TOPIC_FIELDS_TO_BE_STRIPPED = %w(title sticky locked)
  POST_FIELDS_TO_BE_STRIPPED = %w(answer)
end
