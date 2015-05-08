class ApiConstants
  API_CURRENT_VERSION = "v2"
  DEFAULT_PAGINATE_OPTIONS = {
      :per_page => 30,
      :page => 1
  }
  CATEGORY_FIELDS = [:name, :description]
  FORUM_FIELDS = [:name, :description, :forum_category_id, :forum_type, :forum_visibility, :customers]
  UPDATE_TOPIC_FIELDS = {:all => [:title, :message_html, :stamp_type], :edit_topic => [:sticky, :locked], :view_admin => [:created_at, :updated_at], :manage_forums => [:forum_id]}
  CREATE_TOPIC_FIELDS = UPDATE_TOPIC_FIELDS.merge(:view_admin => [:created_at, :updated_at, :email, :user_id])
  UPDATE_POST_FIELDS = {:all => [:body_html, :answer], :view_admin => [:created_at, :updated_at]}
  CREATE_POST_FIELDS = UPDATE_POST_FIELDS.merge(:view_admin => [:created_at, :updated_at, :email, :user_id], :all => [:body_html, :answer, :topic_id])
  LIST_FIELDS = {
      :forum_visibility => Forum::VISIBILITY_KEYS_BY_TOKEN.values.join(","),
      :forum_type => Forum::TYPE_KEYS_BY_TOKEN.values.join(",")
  }
end