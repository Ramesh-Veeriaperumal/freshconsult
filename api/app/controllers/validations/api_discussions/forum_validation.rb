module ApiDiscussions
  class ForumValidation < ApiValidation
    include ActiveModel::Validations

    attr_accessor :name, :forum_type, :forum_category_id, :forum_visibility, :customers
    validates :name, presence: true
    validates :forum_category_id, numericality: true
    validates :forum_visibility, inclusion: { in: ApiConstants::FORUM_VISIBILITY_KEYS_BY_TOKEN }
    validates :forum_type, inclusion: { in: ApiConstants::FORUM_TYPE_KEYS_BY_TOKEN }
    validates :customers, inclusion: { in: [nil], message: 'invalid_field' }, if: proc { |x| x.forum_visibility.to_i != Forum::VISIBILITY_KEYS_BY_TOKEN[:company_users] }
    # customers should be nil if forum has visibility other than 4.
    validates_with DataTypeValidator, rules: { Array => ['customers'] }, if: proc { |x| x.forum_visibility.to_i == Forum::VISIBILITY_KEYS_BY_TOKEN[:company_users] }

    def initialize(request_params, item)
      super(request_params, item)
    end
  end
end
