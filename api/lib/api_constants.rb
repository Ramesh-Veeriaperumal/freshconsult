class ApiConstants
  API_CURRENT_VERSION = "v2"
  DEFAULT_PAGINATE_OPTIONS = {
      :per_page => 30,
      :page => 1
  }
  CATEGORY_FIELDS = [:name, :description]
  FORUM_FIELDS = [:name, :description, :description_html, :forum_category_id, :forum_type, :forum_visibility, :customers]
  LIST_FIELDS = {
      :forum_visibility => Forum::VISIBILITY_KEYS_BY_TOKEN.values.join(","),
      :forum_type => Forum::TYPE_KEYS_BY_TOKEN.values.join(",")
  }
end