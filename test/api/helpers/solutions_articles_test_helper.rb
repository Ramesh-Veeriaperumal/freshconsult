module SolutionsArticlesTestHelper
  def get_article
    @account.solution_category_meta.where(is_default: false).collect(&:solution_folder_meta).flatten.map { |x| x unless x.is_default }.collect(&:solution_article_meta).flatten.collect(&:children).flatten.first
  end

  def get_article_without_draft
    article = @account.solution_category_meta.where(is_default: false).collect(&:solution_folder_meta).flatten.map { |x| x unless x.is_default }.collect(&:solution_article_meta).flatten.collect(&:children).flatten.first
    article.draft.publish! if article.draft.present?
    article.reload
  end

  def get_article_with_draft
    article = @account.solution_category_meta.where(is_default: false).collect(&:solution_folder_meta).flatten.map { |x| x unless x.is_default }.collect(&:solution_article_meta).flatten.collect(&:children).flatten.first
    if article.draft.blank?
      draft = article.build_draft_from_article
      draft.title = 'Sample'
      draft.save
    end
    article.reload
  end

  def get_valid_not_supported_language
    languages = @account.supported_languages + [@account.language]
    Language.all.map(&:code).find { |language| !languages.include?(language) }
  end

  def get_folder_meta
    @account.solution_category_meta.where(is_default: false).collect(&:solution_folder_meta).flatten.map { |x| x unless x.is_default }.first
  end

  def get_category_with_folders
    @account.solution_category_meta.select { |x| x if x.children.count > 0 }.first
  end

  def get_folder_without_translation
    @account.solution_folders.group('parent_id').having('count(*) = 1').first
  end

  def get_folder_with_translation
    @account.solution_folders.group('parent_id').having('count(*) > 1').first
  end

  def get_article_without_translation
    @account.solution_category_meta.where(is_default: false).collect(&:solution_article_meta).flatten.map { |x| x.children if x.children.count == 1 }.flatten.reject(&:blank?).first
  end

  def get_article_with_translation
    @account.solution_category_meta.where(is_default: false).collect(&:solution_article_meta).flatten.map { |x| x.children if x.children.count > 1 }.flatten.reject(&:blank?).first
  end

  def get_default_folder
    @account.solution_folder_meta.where(is_default: true).collect(&:children).flatten.first
  end

  def create_draft(options = {})
    @draft = Solution::Draft.new
    @draft.account = @account
    @draft.article = options[:article]
    @draft.title = 'Sample'
    @draft.category_meta = options[:article].solution_folder_meta.solution_category_meta
    @draft.status = 1
    @draft.keep_previous_author = true if options[:keep_previous_author]
    @draft.user_id = options[:user_id] if options[:user_id]
    @draft.description = '<b>aaa</b>'
    @draft.save

    @draft_body = Solution::DraftBody.new
    @draft_body.draft = @draft
    @draft_body.description = '<b>aaa</b>'
    @draft_body.account = @account
    @draft_body.save
  end
end
