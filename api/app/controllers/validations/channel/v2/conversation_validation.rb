module Channel::V2
  class ConversationValidation < ::ConversationValidation

    CHECK_PARAMS_SET_FIELDS += %w(created_at updated_at).freeze
    attr_accessor :created_at, :updated_at, :import_id, :twitter, :source

    include TimestampsValidationConcern

    validates :import_id, custom_numericality: { only_integer: true, greater_than: 0,
                            allow_nil: true, ignore_string: :allow_string_param }

    validate :twitter_hash_presence?, unless: -> { twitter_reply? }, on: :create

    validates :twitter, data_type: { rules: Hash, required: true },
                        hash: { validatable_fields_hash: proc { |x| x.twitter_fields_validation } }, if: -> { twitter_reply? }, on: :create

    def twitter_reply?
      Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['twitter'] == source
    end

    def twitter_hash_presence?
      errors[:twitter] << :invalid_field if twitter.present?
    end

    def twitter_fields_validation
      {
        tweet_id: { data_type: { rules: Integer, required: true } },
        tweet_type: {
          data_type: { rules: String, required: true },
          custom_inclusion: { in: Channel::V2::ConversationConstants::TWITTER_MSG_TYPES }
        },
        support_handle_id: { data_type: { rules: Integer, required: true } },
        stream_id: { data_type: { rules: Integer, required: true } }
      }
    end
  end
end
