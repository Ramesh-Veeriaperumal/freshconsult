class BotSolutionValidation < ApiValidation
  attr_accessor :category_id, :name, :description, :visibility, :article_id, :folder_id, :title

  validates :category_id, data_type: { rules: Integer }, required: true, on: :create_bot_folder
  validates :visibility, custom_inclusion: { in: Solution::Constants::BOT_VISIBILITIES, detect_type: true, required: true }, on: :create_bot_folder
  validates :name, data_type: { rules: String, required: true }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }, on: :create_bot_folder
  validates :description, data_type: { rules: String, allow_nil: true }, on: :create_bot_folder

  validates :article_id, required: true, custom_numericality: { only_integer: true, greater_than: 0 }, on: :bulk_map_article

  validates :folder_id, required: true, custom_numericality: { only_integer: true, greater_than: 0 }, on: :create_article
  validates :title, required: true, data_type: { rules: String }, custom_length: { maximum: SolutionConstants::TITLE_MAX_LENGTH, minimum: SolutionConstants::TITLE_MIN_LENGTH, message: :too_long_too_short }, on: :create_article
  validates :description, required: true, data_type: { rules: String }, on: :create_article
end
