class ApiSolutions::ArticlesSuggestedValidation < ApiValidation
  attr_accessor :articles_suggested

  validates :articles_suggested,
            data_type: { rules: Array, allow_nil: false },
            array: {
              data_type: { rules: Hash },
              hash: {
                validatable_fields_hash: proc { |x| x.articles_suggested_fields_validation }
              }
            }, required: true

  def articles_suggested_fields_validation
    {
      language: { data_type: { rules: String }, custom_inclusion: { in: Language.all_codes, required: true } },
      article_id: { data_type: { rules: Integer, allow_nil: false }, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: false, ignore_string: :allow_string_param, required: true } }
    }
  end
end
