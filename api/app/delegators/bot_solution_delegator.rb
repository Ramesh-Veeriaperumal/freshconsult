class BotSolutionDelegator < BaseDelegator
  validate :validate_category, on: :create_bot_folder
  validate :valid_article_id?, if: -> { @article_id.present? }
  validate :validate_folder, if: -> { @folder_id.present? }

  def initialize(record, options = {})
    options.each do |key, value|
      instance_variable_set("@#{key}", value)
    end
    super(record, options)
  end

  def validate_category
    errors[:solution_category_meta_id] << :invalid_category_ids unless @bot.category_ids.include?(@category_id)
  end

  def valid_article_id?
    article_meta = Account.current.solution_article_meta.find_by_id(@article_id)
    unless article_meta && article_meta.primary_article.published?
      errors[:article_id] << :invalid_article
      return
    end
    folder_meta,category_meta = article_meta.folder_category_info
    errors[:article_id] << :invalid_bot_article unless folder_meta.visible_to_bot? && @category_ids.include?(category_meta.id)
  end

  def validate_folder
    folder = Account.current.solution_folder_meta.where(id: @folder_id).first
    unless folder
      errors[:folder_id] << :invalid_folder
      return
    end
    errors[:folder_id] << :invalid_folder_visibility unless folder.visible_to_bot?
  end
end
