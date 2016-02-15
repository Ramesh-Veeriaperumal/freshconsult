module ApiDiscussions
  class CategoryValidation < ApiValidation
    attr_accessor :name, :description
    validates :name, data_type: { rules: String, required: true }, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }
    validates :description, data_type: { rules: String, allow_nil: true }

    def initialize(request_params, item)
      super(request_params, item)
    end

    def attributes_to_be_stripped
      DiscussionConstants::CATEGORY_ATTRIBUTES_TO_BE_STRIPPED
    end
  end
end
