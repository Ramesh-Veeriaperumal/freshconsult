module DiscussionConstants
  # ControllerConstants
  CATEGORY_FIELDS = ['name', 'description'].freeze
  FORUM_ARRAY_FIELDS = ['company_ids'].freeze
  CREATE_FORUM_FIELDS = %w(name description forum_type forum_visibility company_ids).freeze | FORUM_ARRAY_FIELDS.map { |x| Hash[x, [nil]] }
  UPDATE_FORUM_FIELDS = CREATE_FORUM_FIELDS << 'forum_category_id'
  UPDATE_TOPIC_FIELDS = { all: %w(title message_html stamp_type sticky locked), manage_forums: ['forum_id'] }.freeze
  CREATE_TOPIC_FIELDS = %w(title message_html stamp_type sticky locked).freeze
  QUESTION_FORUM_TYPE = Forum::TYPE_KEYS_BY_TOKEN[:howto]
  QUESTION_STAMPS = Topic::QUESTIONS_STAMPS_BY_KEY.keys
  FORUM_TO_STAMP_TYPE = {
    Forum::TYPE_KEYS_BY_TOKEN[:announce] => ['null'],
    Forum::TYPE_KEYS_BY_TOKEN[:ideas] => Topic::IDEAS_STAMPS_BY_KEY.keys + ['null'], # nil should always be last, if not, revisit check_stamp_type
    Forum::TYPE_KEYS_BY_TOKEN[:problem] => Topic::PROBLEMS_STAMPS_BY_KEY.keys,
    Forum::TYPE_KEYS_BY_TOKEN[:howto] => {
      QUESTION_STAMPS.first => [QUESTION_STAMPS.last],
      QUESTION_STAMPS.last => [QUESTION_STAMPS.first]
    }
  }
  UPDATE_COMMENT_FIELDS = %w(body_html answer).freeze
  COMMENT_FIELDS = %w(body_html)
  IS_FOLLOWING_FIELDS = ['user_id', 'id'].freeze
  FOLLOW_FIELDS = UNFOLLOW_FIELDS = ['user_id'].freeze
  FOLLOWED_BY_FIELDS = FOLLOW_FIELDS + ApiConstants::PAGINATE_FIELDS

  # ValidationConstants
  FORUM_VISIBILITY_KEYS_BY_TOKEN = Forum::VISIBILITY_KEYS_BY_TOKEN
  FORUM_VISIBILITY = Forum::VISIBILITY_KEYS_BY_TOKEN.values
  FORUM_TYPE = Forum::TYPE_KEYS_BY_TOKEN.values
  LOAD_OBJECT_EXCEPT = [:followed_by, :is_following, :category_forums, :forum_topics, :topic_comments].freeze

  CATEGORY_ATTRIBUTES_TO_BE_STRIPPED = %w(name).freeze
  FORUM_ATTRIBUTES_TO_BE_STRIPPED = %w(name description).freeze
  TOPIC_ATTRIBUTES_TO_BE_STRIPPED = %w(title).freeze
end.freeze
