module ApiDiscussions::Pipe
  class ApiCommentValidation < ApiDiscussions::ApiCommentValidation
    # Appending to the existing constant
    CHECK_PARAMS_SET_FIELDS += %w(created_at updated_at user_id).freeze
    attr_accessor :created_at, :updated_at, :user_id

    # This will include the validations for created_at and updated_at
    include TimestampsValidationConcern

    validates :user_id, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: false, ignore_string: :allow_string_param, required: true }

  end
end
