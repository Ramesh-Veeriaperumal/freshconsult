class DraftValidation < ApiValidation
  attr_accessor :cc_emails, :bcc_emails, :body, :quoted_text, :from_email, :articles_suggested

  validates :body, data_type: { rules: String, required: true, allow_nil: false }, on: :save_draft
  validates :quoted_text, data_type: { rules: String, allow_nil: true }, on: :save_draft
  validates :cc_emails, :bcc_emails, data_type: { rules: Array }, array: { data_type: { rules: String, allow_nil: false }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING } }
  validates :cc_emails, :bcc_emails, custom_length: { maximum: ApiTicketConstants::MAX_EMAIL_COUNT, message_options: { element_type: :values } }
  validates :from_email, data_type: { rules: String, allow_nil: true }
  validate :validate_articles_suggested, if: -> { @request_params[:articles_suggested].present? }

  def initialize(request_params, item, allow_string_param = false)
    super(request_params, item, allow_string_param)
  end

  def validate_articles_suggested
    articles_suggested_validation = ApiSolutions::ArticlesSuggestedValidation.new(articles_suggested: @request_params[:articles_suggested])
    merge_to_parent_errors(articles_suggested_validation) unless articles_suggested_validation.valid?
  end

  private

    def merge_to_parent_errors(validation)
      validation.errors.to_h.each_pair do |key, value|
        errors[key] << value
      end
      error_options.merge! validation.error_options
    end
end
