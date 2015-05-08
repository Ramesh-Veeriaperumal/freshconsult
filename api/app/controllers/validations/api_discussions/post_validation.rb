module ApiDiscussions

	class PostValidation
    include ActiveModel::Validations 
    include ApiValidators

    attr_accessor :user_id, :body_html, :topic_id, :created_at, :updated_at, :answer
    validates :body_html, :topic_id, :presence => true
    validates_with DateTimeValidator, :fields => [:created_at, :updated_at], :allow_nil => true
    validates :answer, inclusion: {in: %w(0 1)}, :allow_blank => true
    validates :topic_id, :user_id, :numericality => {:allow_nil => true}

    def initialize(controller_params, item)
      @topic_id = controller_params["topic_id"] || item.try(:topic_id) 
      @user_id = controller_params["user_id"] || item.try(:user_id) 
      @body_html = controller_params["body_html"] || item.try(:body_html) 
      @answer = controller_params["answer"].to_s
      @created_at = controller_params["created_at"]
      @updated_at = controller_params["updated_at"]
    end 
  end
end