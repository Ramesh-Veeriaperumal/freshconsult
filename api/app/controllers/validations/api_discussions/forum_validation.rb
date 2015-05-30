module ApiDiscussions
  class ForumValidation < ApiValidation
    include ActiveModel::Validations

    attr_accessor :name, :forum_type, :forum_category_id, :forum_visibility
    validates :name, presence: true
    validates :forum_category_id, numericality: true
    validates :forum_visibility, inclusion: { in: ApiConstants::FORUM_VISIBILITY_KEYS_BY_TOKEN }
    validates :forum_type, inclusion: { in: ApiConstants::FORUM_TYPE_KEYS_BY_TOKEN }

    def initialize(request_params, item)
      super(request_params, item)
    end
  end
end
