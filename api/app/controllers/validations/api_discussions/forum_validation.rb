module ApiDiscussions
  class ForumValidation < ApiValidation
    attr_accessor :name, :forum_type, :forum_category_id, :forum_visibility, :customers,
                  :description_html
    validates :name, presence: true
    validates :forum_category_id, numericality: true
    validates :forum_visibility, included: { in: DiscussionConstants::FORUM_VISIBILITY_KEYS_BY_TOKEN }
    validates :forum_type, included: { in: DiscussionConstants::FORUM_TYPE_KEYS_BY_TOKEN }
    validates :customers, inclusion: { in: [nil], message: 'invalid_field' }, if: proc { |x| x.forum_visibility.to_i != Forum::VISIBILITY_KEYS_BY_TOKEN[:company_users] }

    # customers should be nil if forum has visibility other than 4.
    validates :customers, data_type: { rules: Array }, if: proc { |x| x.forum_visibility.to_i == Forum::VISIBILITY_KEYS_BY_TOKEN[:company_users] }
    validates :customers,  array: { numericality: { allow_nil: true } }
    validates :description_html, data_type: { rules: String, allow_nil: true }

    def initialize(request_params, item)
      super(request_params, item)
    end
  end
end
