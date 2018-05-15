module DiscussionConstants
  # ControllerConstants
  CATEGORY_FIELDS = ['name', 'description'].freeze
  FORUM_ARRAY_FIELDS = ['company_ids'].freeze
  CREATE_FORUM_FIELDS = %w(name description forum_type forum_visibility).freeze | FORUM_ARRAY_FIELDS
  UPDATE_FORUM_FIELDS = CREATE_FORUM_FIELDS << 'forum_category_id'
  UPDATE_TOPIC_FIELDS = { all: %w(title message stamp_type sticky locked), manage_forums: ['forum_id'] }.freeze
  CREATE_TOPIC_FIELDS = { all: %w(title message stamp_type sticky locked) }.freeze
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
  }.freeze

  # If :all option is added to this hash, have to assign privilege for this action in privileges.rb
  UPDATE_COMMENT_FIELDS = { edit_topic: %w(body), view_forums: %w(answer) }.freeze

  CREATE_COMMENT_FIELDS = { all: %w(body) }.freeze
  TOPIC_COMMENT_CREATE_FIELDS = { all: %w(body_html) }.freeze
  IS_FOLLOWING_FIELDS = ['user_id', 'id'].freeze
  FOLLOW_FIELDS = UNFOLLOW_FIELDS = ['user_id'].freeze
  FOLLOWED_BY_FIELDS = FOLLOW_FIELDS + ApiConstants::PAGINATE_FIELDS
  PARTICIPATED_BY_FIELDS = ['user_id'].freeze + ApiConstants::PAGINATE_FIELDS

  # Pipe constants
  PIPE_CREATE_COMMENT_FIELDS = { all: CREATE_COMMENT_FIELDS[:all] | %w(created_at updated_at user_id) }.freeze
  PIPE_CREATE_TOPIC_FIELDS = { all: CREATE_TOPIC_FIELDS[:all] | %w(created_at updated_at user_id) }.freeze

  # ValidationConstants
  FORUM_VISIBILITY_KEYS_BY_TOKEN = Forum::VISIBILITY_KEYS_BY_TOKEN
  FORUM_VISIBILITY = Forum::VISIBILITY_KEYS_BY_TOKEN.values
  FORUM_TYPE = Forum::TYPE_KEYS_BY_TOKEN.values
  LOAD_OBJECT_EXCEPT = [:followed_by, :is_following, :category_forums, :forum_topics, :topic_comments, :participated_by].freeze

  CATEGORY_ATTRIBUTES_TO_BE_STRIPPED = %w(name).freeze
  FORUM_ATTRIBUTES_TO_BE_STRIPPED = %w(name description).freeze
  TOPIC_ATTRIBUTES_TO_BE_STRIPPED = %w(title).freeze
end.freeze
