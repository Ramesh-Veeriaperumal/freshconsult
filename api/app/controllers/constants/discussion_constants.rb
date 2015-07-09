module DiscussionConstants
  # ControllerConstants
  CATEGORY_FIELDS = ['name', 'description']
  FORUM_FIELDS = ['name', 'description', 'forum_category_id', 'forum_type', 'forum_visibility', 'customers', 'customers' => []]
  UPDATE_TOPIC_FIELDS = { all: %w(title message_html stamp_type), edit_topic: ['sticky', 'locked'], manage_forums: ['forum_id'] }
  CREATE_TOPIC_FIELDS = UPDATE_TOPIC_FIELDS.merge(manage_users: ['email', 'user_id'])
  UPDATE_POST_FIELDS = { all: ['body_html', 'answer'] }
  CREATE_POST_FIELDS = { all: %w(body_html answer topic_id), manage_users: ['email', 'user_id'] }

  # ValidationConstants
  FORUM_VISIBILITY_KEYS_BY_TOKEN = Forum::VISIBILITY_KEYS_BY_TOKEN.values | Forum::VISIBILITY_KEYS_BY_TOKEN.values.map(&:to_s)
  FORUM_TYPE_KEYS_BY_TOKEN = Forum::TYPE_KEYS_BY_TOKEN.values | Forum::TYPE_KEYS_BY_TOKEN.values.map(&:to_s)
end
