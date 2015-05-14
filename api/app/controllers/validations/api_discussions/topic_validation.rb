module ApiDiscussions
  class TopicValidation
    include ActiveModel::Validations 

    attr_accessor :title, :forum_id, :user_id, :created_at, :updated_at, :sticky, :locked, 
                  :stamp_type, :message_html
    validates :title, :message_html, :presence => true
    validates_with DateTimeValidator, :fields => [:created_at, :updated_at], :allow_nil => true 
    validates :sticky, :locked, inclusion: {in: ApiConstants::BOOLEAN_VALUES}, :allow_blank => true
    validates :forum_id, :numericality => true
    validates :stamp_type, :user_id, :numericality => {:allow_nil => true}

    def initialize(controller_params, item)
      @title = controller_params["title"] || item.try(:title)
      @forum_id = controller_params["forum_id"] || item.try(:forum_id)
      @user_id = controller_params["user_id"] || item.try(:user_id)
      @sticky = controller_params["sticky"]
      @locked = controller_params["locked"]
      @stamp_type = controller_params["stamp_type"] || item.try(:stamp_type)
      @created_at = controller_params["created_at"]
      @updated_at = controller_params["updated_at"]
      @message_html = controller_params["message_html"] || item.try(:first_post).try(:body_html)
    end
  end
end