class Solutions::FolderDecorator < ApiDecorator
  delegate :name, :description, :language_code, :created_at, :updated_at, to: :record
  delegate :id, :is_default, :position, :article_order, :solution_article_meta, :visibility, :customer_folders, :solution_category_meta_id, :folder_visibility_mapping, :solution_platform_mapping, :tags, to: :parent

  include SolutionHelper

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
      category_id: solution_category_meta_id,
      created_at: created_at,
      updated_at: updated_at
    }
    response_hash[:company_ids] = company_ids if company_ids_visible?
    response_hash[:contact_segment_ids] = mappable_ids if contact_segment_ids_visible?
    response_hash[:company_segment_ids] = mappable_ids if company_segment_ids_visible?
    if allow_chat_platform_attributes?
      response_hash[:platforms] = solution_platform_mapping.present? && (!solution_platform_mapping.try(:destroyed?))? solution_platform_mapping.to_hash : SolutionPlatformMapping.default_platform_values_hash
      response_hash[:tags] = !solution_platform_mapping.try(:destroyed?) ? tags.pluck(:name) : []
    end
    if private_api?
      response_hash[:position] = position
      response_hash[:article_order] = article_order
      response_hash[:language] = language_code
    end
    response_hash
  end

  def index_hash
    private_api? ? to_hash : to_hash.except(:category_id)
  end

  def company_ids_visible?
    visibility == Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users]
  end

  def contact_segment_ids_visible?
    visibility == Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:contact_segment]
  end

  def company_segment_ids_visible?
    visibility == Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_segment]
  end

  def parent
    @parent ||= record.parent
  end

  def company_ids
    customer_folders.pluck(:customer_id)
  end

  def mappable_ids
    folder_visibility_mapping.pluck(:mappable_id)
  end

  def company_names
    Account.current.companies.where(id: customer_folders.pluck(:customer_id)).pluck(:name)
  end

  def enriched_hash
    unless is_default
      response_hash = {
        id: id,
        name: name,
        visibility: visibility
      }
      response_hash[:company_names] = company_names if company_ids_visible?
      response_hash
    end
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

  def untranslated_filter_hash
    folder = record.safe_send("#{@lang_code}_available?") ? record.safe_send("#{@lang_code}_folder") : record.primary_folder
    {
      id: record.id,
      name: folder.name,
      language: folder.language_code
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
