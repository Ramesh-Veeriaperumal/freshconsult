module ApiConstants
  
 # ControllerConstants
    API_CURRENT_VERSION = "v2"
    CONTENT_TYPE_REQUIRED_METHODS = ["POST", "PUT"]
    DEFAULT_PAGINATE_OPTIONS = {
        :per_page => 30,
        :page => 1
    }
    CATEGORY_FIELDS = [:name, :description]
    FORUM_FIELDS = [:name, :description, :forum_category_id, :forum_type, :forum_visibility, :customers]
    UPDATE_TOPIC_FIELDS = {:all => [:title, :message_html, :stamp_type], :edit_topic => [:sticky, :locked], :manage_forums => [:forum_id]}
    CREATE_TOPIC_FIELDS = UPDATE_TOPIC_FIELDS.merge(:view_admin => [:created_at, :updated_at], :manage_users => [:email, :user_id])
    UPDATE_POST_FIELDS = {:all => [:body_html, :answer]}
    CREATE_POST_FIELDS = {:all => [:body_html, :answer, :topic_id], :view_admin => [:created_at, :updated_at], :manage_users => [:email, :user_id]}

  # ValidationConstants
    BOOLEAN_VALUES = ["0", 0, false, "1", 1, true]
    LIST_FIELDS = {
        :forum_visibility => Forum::VISIBILITY_KEYS_BY_TOKEN.values.join(","),
        :forum_type => Forum::TYPE_KEYS_BY_TOKEN.values.join(","),
        :sticky => BOOLEAN_VALUES.map(&:to_s).uniq.join(","),
        :locked => BOOLEAN_VALUES.map(&:to_s).uniq.join(",")
    }

  # ErrorConstants
    API_ERROR_CODES = {
        :already_exists => ["has already been taken", "already exists in the selected category"],
        :invalid_value => ["can't be blank", "is not included in the list", "invalid_user"],
        :datatype_mismatch => ["is not a date", "is not a number"],
        :invalid_field => ["invalid_field"],
        :missing_field => ["missing_field"]
    }
    API_HTTP_ERROR_STATUS_BY_CODE = {
        :already_exists => 409
    }
    API_ERROR_CODES_BY_VALUE = Hash[*API_ERROR_CODES.flat_map{|code,errors| errors.flat_map{|error| [error,code]}}]
    
    DEFAULT_CUSTOM_CODE = "invalid_value"
    DEFAULT_HTTP_CODE = 400
end