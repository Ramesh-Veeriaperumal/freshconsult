module Channel::V2
  class ConversationValidation < ::ConversationValidation

    CHECK_PARAMS_SET_FIELDS += %w(created_at updated_at).freeze
    attr_accessor :created_at, :updated_at, :import_id

    include TimestampsValidationConcern

    validates :import_id, custom_numericality: { only_integer: true, greater_than: 0,
                            allow_nil: true, ignore_string: :allow_string_param }
  end
end
