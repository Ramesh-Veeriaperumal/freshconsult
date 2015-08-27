module ApiDiscussions
  class CategoryValidation < ApiValidation
    attr_accessor :name
    validates :name, required: true, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }

    def initialize(request_params, item)
      super(request_params, item)
    end

    def attributes_to_be_stripped
      [:name]
    end
  end
end
