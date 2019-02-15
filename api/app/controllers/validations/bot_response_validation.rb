class BotResponseValidation < ApiValidation
  attr_accessor :articles, :suggested_articles

  validates :articles, presence: true
  validates :articles,
            data_type: { rules: Array },
            array: {
              data_type: { rules: Hash },
              hash: { validatable_fields_hash: proc { |x| x.articles_datatype_validation } }
            }

  validate :validate_article_attribute

  def initialize(request_params, item = nil, allow_string_param = true)
    self.skip_hash_params_set = true
    super(request_params, item, allow_string_param)
  end

  def articles_datatype_validation
    {
      id: { custom_numericality: { only_integer: true, greater_than: 0 }, custom_inclusion: { in: suggested_articles.keys }, required: true },
      agent_feedback: { data_type: { rules: 'Boolean' }, custom_inclusion: { in: [false, true] }, required: true }
    }
  end

  def validate_article_attribute
    articles.each_with_index do |article, index|
      (errors[:"article"] << :"can't be blank") && next if article.empty?
      (errors[:"article"] << :inaccessible_field) && next if suggested_articles[article[:id]].present? && !suggested_articles[article[:id]][:useful].nil?
      param_keys = article.symbolize_keys.keys
      validate_attributes(param_keys, index, :missing_field)
      validate_attributes(param_keys, index, :invalid_field)
    end
  end

  private

    def validate_attributes(param_keys, index, validation)
      attributes = (validation == :missing_field) ? (BotResponseConstants::AGENT_ATTRIBUTES - param_keys) : (param_keys - BotResponseConstants::AGENT_ATTRIBUTES)
      attributes.each do |attribute|
        errors[:"articles[#{index}][#{attribute}]"] << validation
      end
    end
end