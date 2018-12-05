class CannedResponsesValidation < ApiValidation
  include LiquidSyntaxParser
  attr_accessor :title, :content_html, :folder_id, :visibility, :group_ids, :attachments, :attachment_ids, :item
  validates :title, data_type: { rules: String }, allow_nil: false, custom_length: { minimum: 3, maximum: 240, message: :too_long_too_short }
  validates :title, presence: true, on: :create
  validates :content_html, data_type: { rules: String }, allow_nil: false
  validates :content_html, presence: true, on: :create
  validate :validate_content_html_liquid, if: -> { content_html }
  validates :visibility, presence: true, on: :create
  validates :visibility, custom_inclusion: { in: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TYPE.keys, ignore_string: :allow_string_param, detect_type: true }
  validates :folder_id, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param }
  validates :group_ids, data_type: { rules: Array }, array: { custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param } }, allow_nil: true
  validates :group_ids, required: true, if: -> { visibility.to_i == Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups] }
  validates :attachments, required: true, if: -> { @request_params.key? :attachments } # for attachments empty array scenario
  validates :attachments, data_type: { rules: Array, allow_nil: true }, array: { data_type: { rules: ApiConstants::UPLOADED_FILE_TYPE, allow_nil: false } }
  validates :attachments, file_size:  {
    max: proc { |x| x.attachment_limit },
    base_size: proc { |x| x.item }
  }
  validates :attachment_ids, data_type: { rules: Array, allow_nil: false }, array: { custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param } }, allow_nil: false

  def validate_content_html_liquid
    syntax_rescue(@request_params[:content_html], :content_html)
  end
end
