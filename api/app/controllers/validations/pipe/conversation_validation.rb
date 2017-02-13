module Pipe
  class ConversationValidation < ::ConversationValidation
    # Appending to the existing constant
    CHECK_PARAMS_SET_FIELDS += %w(created_at updated_at).freeze
    attr_accessor :created_at, :updated_at

    # This will include the validations for created_at and updated_at
    include TimestampsValidationConcern
  end
end
