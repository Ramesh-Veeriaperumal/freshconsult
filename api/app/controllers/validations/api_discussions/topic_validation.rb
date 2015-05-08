module ApiDiscussions
	class TopicValidation
    include ActiveModel::Validations 
    include ApiMethods

    attr_accessor :title, :forum_id, :user_id, :created_at, :updated_at, :sticky, :locked, 
                  :stamp_type, :message_html
    validates :forum_id, :title, :message_html, :presence => true
    validate :check_date 
    validates :sticky, :locked, inclusion: {in: %w(0 1)}, :allow_blank => true
    validates :stamp_type, :forum_id, :user_id, :numericality => {:allow_nil => true}

    def initialize(controller_params, item)
      @title = controller_params["title"] || item.try(:title)
      @forum_id = controller_params["forum_id"].try(:to_i) || item.try(:forum_id)
      @user_id = controller_params["user_id"].try(:to_i) || item.try(:user_id)
      @sticky = controller_params["sticky"].to_s
      @locked = controller_params["locked"].to_s
      @stamp_type = controller_params["stamp_type"] || item.try(:stamp_type)
      @created_at = controller_params["created_at"]
      @updated_at = controller_params["updated_at"]
      @message_html = controller_params["message_html"] || item.try(:first_post).try(:body_html)
    end

    def check_date
      parse_date(@created_at, :created_at)
      parse_date(@updated_at, :updated_at)
    end
    
 	end
end