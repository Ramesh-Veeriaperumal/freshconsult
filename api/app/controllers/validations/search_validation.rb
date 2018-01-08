class SearchValidation < ApiValidation
  attr_accessor :term, :templates, :context, :limit

  validates :limit, custom_numericality: { only_integer: true, less_than: Search::Utils::MQ_MAX_LIMIT + 1,
    custom_message: :limit_invalid, message_options: { max_value: Search::Utils::MQ_MAX_LIMIT } }
  validates :term, data_type: { rules: String, required: true }
  validates :context, custom_inclusion: { in: Search::Utils::MQ_CONTEXTS }
  validates :templates, data_type: { rules: Array, required: true }
  validate :templates_list, :template_privileges, if: -> { errors[:templates].blank? } 
  # validate :template_features  ### Hack for forums, to be uncommented when forums feature has been migrated to bitmap

  def initialize(request_params)
    super(request_params)
  end

  def templates_list
    valid = templates.all? { |template| Search::Utils::MQ_TEMPLATES.include?(template) }
    unless valid
      errors[:templates] << :not_included
      (error_options[:templates] ||= {}).merge!(list: Search::Utils::MQ_TEMPLATES.join(', '))
    end
  end

  def template_features
    invalid_templates = []
    valid = templates.all? do |template| 
      res = has_features?(template)
      invalid_templates << template unless res
      res
    end
    unless valid
      errors[:templates] << :require_feature
      (error_options[:templates] ||= {}).merge!(feature: invalid_templates.map {|d| ::Search::Utils::TEMPLATE_MAPPING_TO_FEATURES[d]}.join(', ') )
      return false, invalid_templates # Hack for forums, to be removed when forums feature has been migrated to bitmap
    end
    [true, []] # Hack for forums, to be removed when forums feature has been migrated to bitmap
  end

  def template_privileges
    valid = templates.all? { |template| has_privileges?(template) } 
    errors[:templates] << :access_denied unless valid
  end

  private

    def has_features? template
      !(feature = ::Search::Utils::TEMPLATE_MAPPING_TO_FEATURES[template]).present? ||
       Account.current.features?(feature)
    end

    def has_privileges? template
      !(privilege = ::Search::Utils::TEMPLATE_MAPPING_TO_PRIVILEGES[template]).present? ||
         User.current.privilege?(privilege)
    end

end
