class Fixtures::DefaultSolutions

  attr_accessor :account, :user, :article_data

  def initialize(industry)
    @article_data = I18n.t("fixtures.sample_solution_articles.#{industry}").map(&:with_indifferent_access)
  end

  def generate
    article_data.each do |article|
     create_article(article)
    end
  end

  private

  def account
    @account = Account.current
  end

  def user
    @user = User.current
  end

  def create_article(params)
    Solution::Builder.article(solution_article_meta: article_meta_hash(params))
  end

  def article_meta_hash(params)
  {
    primary_article: primary_article_hash(params[:title],params[:description]),
    solution_folder_meta_id: get_folder_id(params),
    art_type: Solution::Constants::TYPE_KEYS_BY_TOKEN[:permanent]
  }
  end

  def primary_article_hash(title,desc)
  {
    title: title,
    description: desc,
    user_id: user.id,
    status: Solution::Article::STATUS_KEYS_BY_TOKEN[:draft]
  }
  end

  def get_folder_id(params)
    folder = account.solution_folders.find_by_name(params[:folder])
    return folder.parent_id if folder.present?
    folder_meta = Solution::Builder.folder(solution_folder_meta: folder_meta_hash(params),language_id: Language.for_current_account.id)
    folder_meta.id
  end

  def folder_meta_hash(params)
  {
    primary_folder: primary_folder_hash(params[:folder]),
    solution_category_meta_id: get_category_id(params),
    visibility: Solution::FolderMeta::VISIBILITY_KEYS_BY_TOKEN[:anyone]
  }
  end

  def primary_folder_hash(folder_name)
  {
    name: folder_name,
    description: "Folder for adding #{folder_name} articles"
  }
  end

  def get_category_id(params)
    category = account.solution_categories.find_by_name(params[:category])
    return category.parent_id if category.present?
    category_meta = Solution::Builder.category(solution_category_meta: category_meta_hash(params), language_id: Language.for_current_account.id)
    category_meta.id
  end

  def category_meta_hash(params)
  {
    primary_category: primary_category_hash(params[:category])
  }
  end

  def primary_category_hash(category_name)
  {
    name: category_name,
    description: "#{category_name} category"
  }
  end

end