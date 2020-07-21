class SolutionArticleFilterValidation < FilterValidation
  attr_accessor :user_id, :language, :portal_id, :author, :status, :approver, :created_at, :last_modified,
                :category, :folder, :tags, :term, :outdated, :article_fields, :platforms

  validates :user_id, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true, ignore_string: :allow_string_param }
  validates :language, required: true, if: :insert_solution_actions?
  validates :language, custom_inclusion: { in: proc { |x| x.allowed_languages },
                                           ignore_string: :allow_string_param }
  validates :portal_id, required: true, data_type: { rules: String, allow_nil: false }, if: :filter_actions
  validates :term, data_type: { rules: String }, on: :filter

  validates :status, custom_inclusion: { in: proc { |x| x.allowed_statuses }, ignore_string: :allow_string_param }, if: :filter_actions
  validates :approver, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param }, if: :filter_actions
  validate  :approver_without_status?, if: :filter_actions
  validates :author, custom_numericality: { only_integer: true, greater_than: -2, ignore_string: :allow_string_param }, if: :filter_export_actions
  validate  :not_zero_author?, if: :filter_export_actions

  validates :outdated, data_type: { rules: 'Boolean' }
  validates :created_at, :last_modified, data_type: { rules: Hash },
                                         hash: { validatable_fields_hash: proc { |x| x.date_fields_validation } }, if: :filter_export_actions
  validates :category, :folder, data_type: { rules: Array }, array: { data_type: { rules: String, allow_nil: false },
                                                                      custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING } }, if: :filter_actions
  validates :tags, data_type: { rules: Array }, array: { data_type: { rules: String },
                                                         custom_length: { maximum: ApiConstants::TAG_MAX_LENGTH_STRING } },
                   string_rejection: { excluded_chars: [','], allow_nil: true }, if: :filter_export_actions
  validates :article_fields, required: true, data_type: { rules: Array }, array: { data_type: { rules: Hash }, hash: { validatable_fields_hash: proc { |x| x.export_fields_validation } } }, on: :export
  validates :platforms, data_type: { rules: Array }, array: { data_type: { rules: String, allow_nil: false },
                                                              custom_inclusion: { in: SolutionConstants::PLATFORM_TYPES } }, if: :filter_actions

  FILTER_ACTIONS = %i[filter export untranslated_articles].freeze
  FILTER_EXPORT_ACTIONS = %i[filter export].freeze

  def initialize(request_params, item = nil, allow_string_param = true)
    super(request_params, item, allow_string_param)
  end

  def allowed_languages
    Account.current.all_languages
  end

  def insert_solution_actions?
    SolutionConstants::INSERT_SOLUTION_ACTIONS.include?(@request_params[:action])
  end

  def allowed_statuses
    default_status_keys = [SolutionConstants::STATUS_FILTER_BY_TOKEN[:draft], SolutionConstants::STATUS_FILTER_BY_TOKEN[:published]]
    default_status_keys.push(SolutionConstants::STATUS_FILTER_BY_TOKEN[:outdated]) if Account.current.multilingual?
    default_status_keys.push([SolutionConstants::STATUS_FILTER_BY_TOKEN[:in_review], SolutionConstants::STATUS_FILTER_BY_TOKEN[:approved]]) if Account.current.article_approval_workflow_enabled?
    default_status_keys.flatten
  end

  def date_fields_validation
    {
      start: { data_type: { rules: String, required: true } },
      end: { data_type: { rules: String, required: true } }
    }
  end

  def filter_actions
    FILTER_ACTIONS.include?(validation_context)
  end

  def filter_export_actions
    FILTER_EXPORT_ACTIONS.include?(validation_context)
  end

  def article_export_fields_list
    SolutionConstants::ARTICLE_EXPORT_HEADER_MASTER_LIST
  end

  def export_fields_validation
    {
      field_name: { data_type: { rules: String, required: true }, custom_inclusion: { in: export_master_header_list } },
      column_name: { data_type: { rules: String, required: true } }
    }
  end

  def approver_without_status?
    status = @request_params[:status].to_i
    if ![SolutionConstants::STATUS_FILTER_BY_TOKEN[:approved], SolutionConstants::STATUS_FILTER_BY_TOKEN[:in_review]].include?(status) && @request_params[:approver].present?
      errors.add(:message, 'to select approver status should be in_review or approved')
      return false
    end
  end

  def numeric?(check)
    true if Integer(check) rescue false
  end

  def not_zero_author?
    if @request_params[:author].present?
      if @request_params[:author].to_i.zero? && numeric?(@request_params[:author])
        errors.add(:message, 'It should be a/an Positive Integer')
        return false
      end
    end
    true
  end

  private

    def export_master_header_list
      if Account.current.suggested_articles_count_enabled?
        SolutionConstants::EXPORT_HEADER_LIST_WITH_SUGGESTED_FEATURE
      else
        SolutionConstants::ARTICLE_EXPORT_HEADER_MASTER_LIST
      end
    end
end
