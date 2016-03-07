module ApiDiscussions
  class ForumValidation < ApiValidation
    attr_accessor :name, :forum_type, :forum_category_id, :forum_visibility, :company_ids,
                  :description, :topics_count
    validates :name, data_type: { rules: String, required: true }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
    validates :forum_category_id, custom_numericality: { only_integer: true, greater_than: 0, required: true }, on: :update
    validates :forum_visibility, custom_inclusion: { in: DiscussionConstants::FORUM_VISIBILITY, detect_type: true, required: true }

    # Forum type can't be updated if the forum has any topics. Can be updated only if no topics found for forum.
    validates :forum_type, custom_absence: { allow_nil: false, message: :cannot_set_forum_type }, if: -> { @topics_count.to_i > 0 }
    validates :forum_type, custom_inclusion: { in: DiscussionConstants::FORUM_TYPE, detect_type: true, required: true }, if: -> { @topics_count.to_i == 0 }
    validates :company_ids, custom_absence: { allow_nil: false, message: :cannot_set_company_ids }, if: -> { errors[:forum_visibility].blank? && company_ids_not_allowed? }
    # company_ids should be nil if forum has visibility other than 4.
    validates :company_ids, data_type: { rules: Array }, array: { custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true } }, unless: -> { errors[:forum_visibility].present? || company_ids_not_allowed? }
    validates :description, data_type: { rules: String, allow_nil: true }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }

    def initialize(request_params, item)
      super(request_params, item)
      check_params_set(request_params, item)
      @topics_count = item.topics_count.to_i if item
      @forum_type = request_params['forum_type'] if request_params.key?('forum_type')
    end

    def company_ids_not_allowed?
      forum_visibility.to_i != DiscussionConstants::FORUM_VISIBILITY_KEYS_BY_TOKEN[:company_users]
    end

    def attributes_to_be_stripped
      DiscussionConstants::FORUM_ATTRIBUTES_TO_BE_STRIPPED
    end
  end
end
