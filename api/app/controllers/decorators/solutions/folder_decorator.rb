class Solutions::FolderDecorator < ApiDecorator
  delegate :name, :description, :language_code, to: :record

  delegate :id, :position, :article_order, :solution_article_meta, :visibility, :customer_folders, :solution_category_meta_id, to: :parent

  def initialize(record, options = {})
    super(record)
    @lang_code = options[:language_code]
  end

  def to_hash
    response_hash = {
      id: id,
      name: name,
      description: description,
      visibility: visibility,
      created_at: created_at,
      updated_at: updated_at
    }
    response_hash[:company_ids] = company_ids if company_ids_visible?
    response_hash[:category_id] = category_id if private_api?
    response_hash[:position] = position if private_api?
    response_hash[:article_order] = article_order if private_api?
    response_hash
  end

  def company_ids_visible?
    visibility == Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users]
  end

  def parent
    @parent ||= record.parent
  end

  def company_ids
    customer_folders.map(&:customer_id)
  end

  def category_id
    solution_category_meta_id
  end

  def summary_hash
    {
      id: id,
      name: name,
      language: language_code,
      articles_count: articles_count,
      position: position
    }
  end

  private

    def current_language_articles
      solution_article_meta.map { |article_meta| article_meta.safe_send("#{@lang_code}_article") }.compact
    end

    def articles_count
      current_language_articles.length
    end
end
