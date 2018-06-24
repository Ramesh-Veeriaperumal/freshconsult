class CannedFormValidation < ApiValidation
  include CannedFormConstants
  include Redis::OthersRedis

  attr_accessor :name, :welcome_text, :thankyou_text, :version, :fields

  validate :validate_form_limit, on: :create
  validates :name, data_type: { rules: String, allow_nil: false }
  validates :welcome_text, data_type: { rules: String, allow_nil: true }
  validates :thankyou_text, data_type: { rules: String, allow_nil: true }

  validates :fields,
            data_type: { rules: Array },
            array: {
              data_type: { rules: Hash },
              allow_nil: true,
              hash: {
                name: {
                  required: true,
                  custom_format: { with: FIELD_NAME_REGEX, accepted: SUPPORTED_FIELDS.join(',') }
                },
                position: {
                  required: true
                }
              }
            }

  validate :validate_fields_length, if: -> { errors[:fields].empty? && fields.present? }
  validate :validate_field_choices_length, if: -> { errors[:fields].empty? && fields.present? }

  def validate_form_limit
    form_count = Account.current.canned_forms.active_forms.count
    allowed_no_of_forms = get_others_redis_key(canned_form_key) || MAX_NO_OF_FORMS
    if form_count >= allowed_no_of_forms.to_i
      errors[:form] << :max_limit
      error_options[:form] = { name: 'form', max_value: allowed_no_of_forms }
    end
  end

  def validate_fields_length
    fields_length = fields.reject { |x| x['deleted'] == true }.length
    validate_length(:fields, fields_length, MIN_FIELD_LIMIT, MAX_FIELD_LIMIT)
  end

  def validate_field_choices_length
    fields.each do |field|
      next if field['deleted']
      field_name = field['name'].split('_')[0]
      if MULTI_CHOICE_FIELDS.include? field_name
        choice_length = field['choices'].reject { |x| x['_destroy'] == true }.length
        validate_length(:choices, choice_length, MIN_CHOICE_LIMIT, MAX_CHOICE_LIMIT)
      end
    end
  end

  private

    def validate_length(type, length, min, max)
      if length < min || length > max
        errors[:fields] << :too_long_too_short
        self.error_options.merge!(fields: { element_type: type, min_count: min, current_count: length, max_count: max })
      end
    end

    def canned_form_key
      format(Redis::RedisKeys::CANNED_FORMS, account_id: Account.current.id)
    end
end
