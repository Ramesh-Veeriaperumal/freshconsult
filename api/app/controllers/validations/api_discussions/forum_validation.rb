module ApiDiscussions
  class ForumValidation
    include ActiveModel::Validations

    attr_accessor :name, :forum_type, :forum_category_id, :forum_visibility
    validates :name, presence: true
    validates :forum_category_id, numericality: true
    validates :forum_visibility, inclusion: { in: Forum::VISIBILITY_KEYS_BY_TOKEN.values }
    validates :forum_type, inclusion: { in: Forum::TYPE_KEYS_BY_TOKEN.values }

    def initialize(controller_params, item)
      @name = controller_params['name'] || item.try(:name)
      @forum_category_id = controller_params['forum_category_id'] || item.try(:forum_category_id)
      @forum_type = try_to_i(controller_params['forum_type']) || item.try(:forum_type)
      @forum_visibility = try_to_i(controller_params['forum_visibility']) || item.try(:forum_visibility)
    end

    def try_to_i(value)
      value.try(:to_i) if value.respond_to?(:to_i)
    end
  end
end
