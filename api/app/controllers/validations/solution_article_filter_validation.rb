class SolutionArticleFilterValidation < FilterValidation
  attr_accessor :user_id, :language_id

  validates :user_id, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true, ignore_string: :allow_string_param }
  validates :language_id, required: true, custom_inclusion: { in: proc { |x| x.portal_languages }, ignore_string: :allow_string_param }

  def initialize(request_params, item = nil, allow_string_param = true)
    super(request_params, item, allow_string_param)
  end

  def portal_languages
    Account.current.all_portal_language_objects.map(&:id)
  end
end
