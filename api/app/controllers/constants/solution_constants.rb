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
                               seo_data attachments attachments_list cloud_file_attachments tags outdated unlock].map(&:to_sym).freeze

  ARTICLE_ARRAY_FIELDS = %w[tags attachments attachments_list cloud_file_attachments].freeze
  ARTICLE_FIELDS = (%w[category_name folder_name description
                       title status seo_data type folder_id session unlock] | ARTICLE_ARRAY_FIELDS |
                   ['seo_data' => ARTICLE_SEO_DATA_FIELDS]).freeze
  ARTICLE_PROPERTY_FIELDS = %w[tags seo_data user_id folder_id type outdated].freeze

  CREATE_ARTICLE_FIELDS = { all: ARTICLE_FIELDS }.freeze
  UPDATE_ARTICLE_FIELDS = { all: ARTICLE_FIELDS | ['outdated'], admin_tasks: ['agent_id'] }.freeze

  SEND_FOR_REVIEW_FIELDS = %w[approver_id].freeze

  FILTER_ATTRIBUTES = %w[author status approver outdated created_at last_modified tags category folder].freeze
  FILTER_FIELDS = %w[portal_id language term page per_page].freeze | FILTER_ATTRIBUTES
  ADVANCED_FILTER_FIELDS = %w[created_at last_modified tags category folder].freeze

  ARTICLE_EXPORT_HEADER_MASTER_LIST = %w[id title live status author_name author_id created_at tags modified_at recent_author_name language_code url hits thumbs_up thumbs_down feedback_count seo_title seo_description folder_id folder_name category_id category_name].freeze
  EXPORT_FIELDS = (%w[portal_id language article_fields] | FILTER_ATTRIBUTES).freeze

  IGNORE_PARAMS = %w[folder_id attachments_list cloud_file_attachments unlock].freeze

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

  FILTER_PRELOAD_OPTIONS = [{ solution_article_meta: [:solution_folder_meta, :solution_category_meta] }, { draft: :draft_body }, :tags, { helpdesk_approval: :approver_mappings }].freeze

  EXPORT_PRELOAD_OPTIONS = [{ solution_article_meta: [:solution_folder_meta, :solution_category_meta] }, { draft: [:draft_body, :user] }, :user, :tags].freeze

  LOAD_OBJECT_EXCEPT = [:category_folders, :folder_articles, :article_content, :filter, :untranslated_articles].freeze

  INDEX_FIELDS = %w[language prefer_published].freeze

  RECENT_ARTICLES_FIELDS = %w[ids user_id language].freeze
  ARTICLE_CONTENT_FIELDS = %w[language].freeze
  REORDER_FIELDS = %w[position portal_id].freeze

  KBASE_EMAIL_SOURCE = 'kbase_email'.freeze
  UNTRANSLATED_ARTICLES_FIELDS = %w[portal_id language category folder status page per_page].freeze
  INSERT_SOLUTION_ACTIONS = %w[index article_content].freeze

  ARTICLES_PRIVATE_CONTROLLER = 'ember/solutions/articles'.freeze

  SUMMARY_LIMIT = 3
end
