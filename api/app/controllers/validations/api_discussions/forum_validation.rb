module ApiDiscussions
  class ForumValidation < ApiValidation
    attr_accessor :name, :forum_type, :forum_category_id, :forum_visibility, :customers,
                  :description_html, :topics_count
    validates :name, required: true
    validates :forum_category_id, numericality: true
    validates :forum_visibility, custom_inclusion: { in: DiscussionConstants::FORUM_VISIBILITY_KEYS_BY_TOKEN }

    # Forum type can't be updated if the forum has any topics. Can be updated only if no topics found for forum.
    validates :forum_type, inclusion: { in: [nil], message: 'invalid_field' }, if: -> { @topics_count.to_i > 0 && @forum_type_set }
    validates :forum_type, custom_inclusion: { in: DiscussionConstants::FORUM_TYPE_KEYS_BY_TOKEN }, if: -> { @topics_count.to_i == 0 }
    validates :customers, inclusion: { in: [nil], message: 'invalid_field' }, if: proc { |x| x.forum_visibility.to_i != Forum::VISIBILITY_KEYS_BY_TOKEN[:company_users] }

    # customers should be nil if forum has visibility other than 4.
    validates :customers, data_type: { rules: Array, allow_nil: true }, if: proc { |x| x.forum_visibility.to_i == Forum::VISIBILITY_KEYS_BY_TOKEN[:company_users] }
    validates :customers,  array: { numericality: { allow_nil: true } }
    validates :description_html, data_type: { rules: String, allow_nil: true }

    def initialize(request_params, item)
      super(request_params, item)
      check_params_set(request_params, item)
      @topics_count = item.topics_count.to_i if item
      @forum_type = request_params.key?('forum_type') ? request_params['forum_type'] : item.try('forum_type')
    end
  end
end
