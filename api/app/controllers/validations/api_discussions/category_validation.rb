module ApiDiscussions
  class CategoryValidation < ApiValidation
    attr_accessor :name
    validates :name, required: true

    def initialize(request_params, item)
      super(request_params, item)
    end
  end
end
