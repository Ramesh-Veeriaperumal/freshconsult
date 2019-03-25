module Settings
  class HelpdeskValidation < ApiValidation
    include Settings::HelpdeskConstants
    validates :primary_language, data_type: { rules: String }, allow_nil: true, on: :update
    validates :supported_languages, data_type: { rules: Array, allow_blank: true }, on: :update
    validates :portal_languages, data_type: { rules: Array, allow_blank: true }, array: { data_type: { rules: String }, custom_inclusion: { in: proc { |x| x.supported_languages } } }, if: -> { errors.blank? && @request_params['portal_languages'].present? }, on: :update
    validate :check_feature_enable_multilingual, if: -> { errors.blank? && primary_language_update? }, on: :update
    validate :validate_primary_language, if: -> { errors.blank? && @request_params['primary_language'].present? }, on: :update
    validate :validate_supported_language, if: -> { errors.blank? && @request_params['supported_languages'].present? }, on: :update
    validate :validate_primary_being_added_supported, if: -> { errors.blank? }, on: :update
    validate :update_primary_or_supported, if: -> { errors.blank? }
    validate :check_feature_multilanguage, if: -> { errors.blank? && (!@request_params['supported_languages'].nil? || !@request_params['portal_languages'].nil?) }

    def languages
      Language.all_codes
    end

    def initialize(request_params, item = nil, allow_string_param = false)
      @item = item
      super(request_params, item, allow_string_param)
    end

    def primary_language
      @request_params['primary_language'] || @item.main_portal.language
    end

    def supported_languages
      @request_params['supported_languages'] || @item.supported_languages
    end

    def portal_languages
      @request_params['portal_languages'] || @item.portal_languages
    end

    def validate_primary_being_added_supported
      errors[:supported_languages] = :supported_language_primary if supported_languages.include? primary_language
    end

    def update_primary_or_supported
      errors[:primary] = :primary_or_supported if primary_language_update? && (supported_languages_update? || portal_languages_update?)
    end

    def check_feature_enable_multilingual
      errors[:feature] = :supported_previously_added if @item.features_included?(:enable_multilingual)
    end

    def check_feature_multilanguage
      unless @item.features_included?(:multi_language)
        errors[:feature] = :require_feature_for_attribute
        error_options[:feature] = { feature: :multi_language, attribute: (@request_params['supported_languages'] || @request_params['portal_languages']).join(',') }
      end
    end

    def validate_primary_language
      if languages.exclude? primary_language
        errors[:primary_language] = :invalid_language
        error_options[:primary_language] = { languages: @request_params['primary_language'] }
      end
    end

    def validate_supported_language
      invalid_languages = supported_languages - languages
      if invalid_languages.present?
        errors[:supported_languages] = :invalid_language
        error_options[:supported_languages] = { languages: invalid_languages }
      end
    end

    private

      def primary_language_update?
        @primary_language_update ||= @request_params['primary_language'].present? && (@request_params['primary_language'] != @item.main_portal.language)
      end

      def supported_languages_update?
        @supported_languages_update ||= @request_params['supported_languages'].present? && (@request_params['supported_languages'] != @item.supported_languages)
      end

      def portal_languages_update?
        @portal_languages_update ||= @request_params['portal_languages'].present? && (@request_params['portal_languages'] != @item.portal_languages)
      end
  end
end
