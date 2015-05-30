module ApiDiscussions
  class CategoryValidation < ApiValidation
    include ActiveModel::Validations

    attr_accessor :name
    validates :name, presence: true

    def initialize(request_params, item)
      super(request_params, item)
    end
  end
end
