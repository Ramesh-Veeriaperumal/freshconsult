module SolutionConstants
  CATEGORY_FIELDS = %w[description name visible_in_portals].freeze

  CATEGORY_ATTRIBUTES_TO_BE_STRIPPED = %w[name].freeze

  FOLDER_FIELDS = %w[description name visibility company_ids category_id].freeze

  FOLDER_FIELDS_PRIVATE_API = FOLDER_FIELDS | %w[article_order]

  FOLDER_ATTRIBUTES_TO_BE_STRIPPED = %w[name].freeze

  BULK_UPDATE_FIELDS = %w[properties].freeze

  BULK_UPDATE_FOLDER_PROPERTIES = %w[category_id visibility].freeze

  ARTICLE_SEO_DATA_FIELDS = %w[meta_title meta_description meta_keywords].freeze
  ARTICLE_LANGUAGE_FIELDS = %w[title description status
                               seo_data attachments attachments_list cloud_file_attachments tags unlock].map(&:to_sym).freeze

  ARTICLE_ARRAY_FIELDS = %w[tags attachments attachments_list cloud_file_attachments].freeze
  ARTICLE_FIELDS = %w[category_name folder_name description
                      title status seo_data type folder_id unlock].freeze | ARTICLE_ARRAY_FIELDS |
                   ['seo_data' => ARTICLE_SEO_DATA_FIELDS]
  ARTICLE_PROPERTY_FIELDS = %w[tags seo_data user_id folder_id type].freeze

  CREATE_ARTICLE_FIELDS = { all: ARTICLE_FIELDS }.freeze
  UPDATE_ARTICLE_FIELDS = { all: ARTICLE_FIELDS, admin_tasks: ['agent_id'] }.freeze

  FILTER_ATTRIBUTES = %w[author status created_at last_modified tags category folder].freeze
  FILTER_FIELDS = %w[portal_id language_id term page per_page].freeze | FILTER_ATTRIBUTES

  IGNORE_PARAMS = %w[folder_id unlock attachments_list cloud_file_attachments].freeze

  ARTICLE_ATTRIBUTES_TO_BE_STRIPPED = %w[title category_name folder_name].freeze

  ARTICLE_WRAP_PARAMS = [:article, exclude: [],
                                   format: [:json, :multipart_form]].freeze

  ARTICLE_ALLOWED_CONTENT_TYPE_FOR_ACTION = {
    create: [:json, :multipart_form],
    update: [:json, :multipart_form]
  }.freeze

  BULK_UPDATE_ARTICLE_PROPERTIES = %w[folder_id user_id tags].freeze

  TITLE_MAX_LENGTH = 240
  TITLE_MIN_LENGTH = 3

  INDEX_PRELOAD_OPTIONS = [{ solution_article_meta: [:solution_folder_meta, :solution_category_meta] }, :article_body, { article_ticket: :ticketable }, :draft, draft: :draft_body].freeze

  FILTER_PRELOAD_OPTIONS = [{ solution_article_meta: [:solution_folder_meta, :solution_category_meta] }, :draft, :article_ticket, {article_ticket: :ticketable} , :tags, tags: :tag_uses].freeze

  LOAD_OBJECT_EXCEPT = [:category_folders, :folder_articles, :article_content, :filter].freeze

  INDEX_FIELDS = %w[language].freeze
  RECENT_ARTICLES_FIELDS = %w[ids user_id language_id].freeze
  ARTICLE_CONTENT_FIELDS = %w[language_id].freeze
  REORDER_FIELDS = %w[position portal_id].freeze
  KBASE_EMAIL_SOURCE = "kbase_email".freeze
end
