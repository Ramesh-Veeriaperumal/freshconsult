module ApiDiscussions
  class ForumValidation < ApiValidation
    attr_accessor :name, :forum_type, :forum_category_id, :forum_visibility, :company_ids,
                  :description, :topics_count
    validates :name, required: true, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }
    validates :forum_category_id, required: { allow_nil: false, message: :required_and_numericality }, on: :update
    validates :forum_category_id, custom_numericality: { allow_nil: true }, on: :update
    validates :forum_visibility, custom_inclusion: { in: DiscussionConstants::FORUM_VISIBILITY, required: true }

    # Forum type can't be updated if the forum has any topics. Can be updated only if no topics found for forum.
    validates :forum_type, custom_absence: { allow_nil: false, message: :invalid_field }, if: -> { @topics_count.to_i > 0 && @forum_type_set }
    validates :forum_type, custom_inclusion: { in: DiscussionConstants::FORUM_TYPE, required: true }, if: -> { @topics_count.to_i == 0 }
    validates :company_ids, custom_absence: { allow_nil: false, message: :invalid_field }, if: proc { |x| x.forum_visibility.to_i != DiscussionConstants::FORUM_VISIBILITY_KEYS_BY_TOKEN[:company_users] }

    # company_ids should be nil if forum has visibility other than 4.
    validates :company_ids, data_type: { rules: Array }, if: proc { |x| x.forum_visibility.to_i == DiscussionConstants::FORUM_VISIBILITY_KEYS_BY_TOKEN[:company_users] }
    validates :company_ids,  array: { custom_numericality: { allow_nil: true } }
    validates :description, data_type: { rules: String, allow_nil: true }, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }

    def initialize(request_params, item)
      super(request_params, item)
      check_params_set(request_params, item)
      @topics_count = item.topics_count.to_i if item
      @forum_type = request_params['forum_type'] if request_params.key?('forum_type')
    end

    def attributes_to_be_stripped
      DiscussionConstants::FORUM_FIELDS_TO_BE_STRIPPED
    end
  end
end
