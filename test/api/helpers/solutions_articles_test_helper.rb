module SolutionsArticlesTestHelper
  def get_article(language = Account.current.language_object)
    @account.solution_category_meta.where(is_default: false).collect(&:solution_folder_meta).flatten.map { |x| x unless x.is_default }.collect(&:solution_article_meta).flatten.collect(&:children).flatten.select{ |art| art.language_id == language.id }.first
  end

  def get_article_without_draft(language = Account.current.language_object)
    article = @account.solution_category_meta.where(is_default: false).collect(&:solution_folder_meta).flatten.map { |x| x unless x.is_default }.collect(&:solution_article_meta).flatten.collect(&:children).flatten.select{ |art| art.language_id == language.id }.first
    article.draft.publish! if article.draft.present?
    article.reload
  end

  def get_article_with_draft(language = Account.current.language_object)
    article = @account.solution_category_meta.where(is_default: false).collect(&:solution_folder_meta).flatten.map { |x| x unless x.is_default }.collect(&:solution_article_meta).flatten.collect(&:children).flatten.select{ |art| art.language_id == language.id }.first
    if article.draft.blank?
      draft = article.build_draft_from_article
      draft.title = 'Sample'
      draft.save
    end
    article.reload
  end

  def without_publish_solution_privilege
    User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
    User.any_instance.stubs(:privilege?).with(:publish_solution).returns(false)
    yield
  ensure
     User.any_instance.unstub(:privilege?)
  end

  def with_publish_solution_privilege
    User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
    User.any_instance.stubs(:privilege?).with(:publish_solution).returns(true)
    yield
  ensure
     User.any_instance.unstub(:privilege?)
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
    article = options[:article]
    return article.draft if article.draft

    @draft = Solution::Draft.new
    @draft.account = @account
    @draft.article = options[:article]
    @draft.title = 'Sample'
    @draft.category_meta = options[:article].solution_folder_meta.solution_category_meta
    @draft.status = 1
    @draft.keep_previous_author = true if options[:keep_previous_author]
    @draft.user_id = options[:user_id] if options[:user_id]
    @draft.description = '<b>aaa</b>'
    @draft.save!

    @draft_body = Solution::DraftBody.new
    @draft_body.draft = @draft
    @draft_body.description = '<b>draft body</b>'
    @draft_body.account = @account
    @draft_body.save!
  end

  def populate_articles(folder_meta, bulk = false)
    return if folder_meta.article_count > 10 && bulk == false

    (1..10).each do |i|
      articlemeta = Solution::ArticleMeta.new
      articlemeta.art_type = 1
      articlemeta.solution_folder_meta_id = folder_meta.id
      articlemeta.solution_category_meta = folder_meta.solution_category_meta
      articlemeta.account_id = @account.id
      articlemeta.published = false
      articlemeta.save

      article_with_lang = Solution::Article.new
      article_with_lang.title = "#{Faker::Name.name} #{i}"
      article_with_lang.description = '<b>aaa</b>'
      article_with_lang.status = 1
      article_with_lang.language_id = @account.language_object.id
      article_with_lang.parent_id = articlemeta.id
      article_with_lang.account_id = @account.id
      article_with_lang.user_id = @account.agents.first.id
      article_with_lang.save
    end
  end

  def setup_redis_for_articles
    $redis_others.perform_redis_op('set', 'ARTICLE_SPAM_REGEX', '(gmail|kindle|face.?book|apple|microsoft|google|aol|hotmail|aim|mozilla|quickbooks|norton).*(support|phone|number)')
    $redis_others.perform_redis_op('set', 'PHONE_NUMBER_SPAM_REGEX', '(1|I)..?8(1|I)8..?85(0|O)..?78(0|O)6|(1|I)..?877..?345..?3847|(1|I)..?877..?37(0|O)..?3(1|I)89|(1|I)..?8(0|O)(0|O)..?79(0|O)..?9(1|I)86|(1|I)..?8(0|O)(0|O)..?436..?(0|O)259|(1|I)..?8(0|O)(0|O)..?969..?(1|I)649|(1|I)..?844..?922..?7448|(1|I)..?8(0|O)(0|O)..?75(0|O)..?6584|(1|I)..?8(0|O)(0|O)..?6(0|O)4..?(1|I)88(0|O)|(1|I)..?877..?242..?364(1|I)|(1|I)..?844..?782..?8(0|O)96|(1|I)..?844..?895..?(0|O)4(1|I)(0|O)|(1|I)..?844..?2(0|O)4..?9294|(1|I)..?8(0|O)(0|O)..?2(1|I)3..?2(1|I)7(1|I)|(1|I)..?855..?58(0|O)..?(1|I)8(0|O)8|(1|I)..?877..?424..?6647|(1|I)..?877..?37(0|O)..?3(1|I)89|(1|I)..?844..?83(0|O)..?8555|(1|I)..?8(0|O)(0|O)..?6(1|I)(1|I)..?5(0|O)(0|O)7|(1|I)..?8(0|O)(0|O)..?584..?46(1|I)(1|I)|(1|I)..?844..?389..?5696|(1|I)..?844..?483..?(0|O)332|(1|I)..?844..?78(0|O)..?675(1|I)|(1|I)..?8(0|O)(0|O)..?596..?(1|I)(0|O)65|(1|I)..?888..?573..?5222|(1|I)..?855..?4(0|O)9..?(1|I)555|(1|I)..?844..?436..?(1|I)893|(1|I)..?8(0|O)(0|O)..?89(1|I)..?4(0|O)(0|O)8|(1|I)..?855..?662..?4436')
    $redis_others.perform_redis_op('set', 'CONTENT_SPAM_CHAR_REGEX', 'ℴ|ℕ|ℓ|ℳ|ℱ|ℋ|ℝ|ⅈ|ℯ|ℂ|○|ℬ|ℂ|ℙ|ℹ|ℒ|ⅉ|ℐ')
  end

  def get_valid_not_supported_language(account = @account || Account.current)
    languages = account.supported_languages + [account.language]
    Language.all.map(&:code).find { |language| !languages.include?(language) }
  end

  def approver_record(article)
    @approver_record = approval_record(article).approver_mappings.first
  end

  def approval_record(article)
    @approval_record = article.helpdesk_approval
  end
end
