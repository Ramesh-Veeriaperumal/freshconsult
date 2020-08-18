module SolutionConstants
  CATEGORY_FIELDS = %w[description name visible_in_portals].freeze

  CATEGORY_ATTRIBUTES_TO_BE_STRIPPED = %w[name].freeze

  FOLDER_FIELDS = %w[description name visibility company_ids category_id contact_segment_ids company_segment_ids platforms tags icon].freeze

  FOLDER_FIELDS_PRIVATE_API = FOLDER_FIELDS | %w[article_order]

  FOLDER_FILTER_FIELDS = %w[portal_id language platforms tags per_page page].freeze
  FOLDER_ATTRIBUTES_TO_BE_STRIPPED = %w[name].freeze

  BULK_UPDATE_FIELDS = %w[properties].freeze

  BULK_UPDATE_FOLDER_PROPERTIES = %w[category_id visibility].freeze

  ARTICLE_SEO_DATA_FIELDS = %w[meta_title meta_description meta_keywords].freeze

  UPDATEABLE_ARTICLE_META_FIELDS = %w[folder_id art_type solution_folder_meta_id platforms].freeze
  ARTICLE_META_FIELDS = (UPDATEABLE_ARTICLE_META_FIELDS | %w[id]).freeze

  UPDATEABLE_ARTICLE_LANGUAGE_FIELDS = ARTICLE_LANGUAGE_FIELDS = %w[title description status seo_data attachments attachments_list cloud_file_attachments tags outdated user_id templates_used].freeze

  DRAFT_FIELDS = %w[title description attachments attachments_list cloud_file_attachments unlock].freeze

  ARTICLE_ARRAY_FIELDS = %w[tags attachments attachments_list cloud_file_attachments].freeze
  # all fields possible in update or create API call
  ARTICLE_API_FIELDS = (%w[category_name folder_name description
                           title status seo_data type folder_id session unlock templates_used platforms] | ARTICLE_ARRAY_FIELDS |
                   ['seo_data' => ARTICLE_SEO_DATA_FIELDS]).freeze

  CREATE_ARTICLE_FIELDS = { all: ARTICLE_API_FIELDS }.freeze
  # for mark as outdated and uptodate, we can pass outdated along with all other params
  UPDATE_ARTICLE_FIELDS = { all: ARTICLE_API_FIELDS | ['outdated'], admin_tasks: ['agent_id'] }.freeze

  SEND_FOR_REVIEW_FIELDS = %w[approver_id].freeze

  FILTER_AND_EXPORT_ATTRIBUTES = %w[author status approver outdated created_at last_modified tags category folder].freeze
  FILTER_ATTRIBUTES = (%w[platforms] | FILTER_AND_EXPORT_ATTRIBUTES).freeze
  FILTER_FIELDS = %w[portal_id language term page per_page].freeze | FILTER_ATTRIBUTES
  ADVANCED_FILTER_FIELDS = %w[created_at last_modified tags category folder].freeze

  ARTICLE_EXPORT_HEADER_MASTER_LIST = %w[id title live status author_name author_id created_at tags modified_at recent_author_name language_code url hits thumbs_up thumbs_down feedback_count seo_title seo_description folder_id folder_name category_id category_name].freeze
  EXPORT_HEADER_LIST_WITH_SUGGESTED_FEATURE = (%w[suggested] | ARTICLE_EXPORT_HEADER_MASTER_LIST).freeze

  EXPORT_FIELDS = (%w[portal_id language article_fields] | FILTER_AND_EXPORT_ATTRIBUTES).freeze

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

  LOAD_OBJECT_EXCEPT = [:category_folders, :folder_articles, :article_content, :filter, :untranslated_articles, :suggested, :folder_filter].freeze

  INDEX_FIELDS = %w[language prefer_published].freeze
  SHOW_FIELDS = %w[language prefer_published status].freeze

  FOLDER_ARTICLES_FIELDS = (%w[portal_id tags platforms page per_page status] | INDEX_FIELDS).freeze

  RECENT_ARTICLES_FIELDS = %w[ids user_id language].freeze
  ARTICLE_CONTENT_FIELDS = %w[language prefer_published].freeze
  REORDER_FIELDS = %w[position portal_id].freeze
  SUGGESTED_FIELDS = %w[articles_suggested].freeze

  KBASE_EMAIL_SOURCE = 'kbase_email'.freeze
  UNTRANSLATED_ARTICLES_FIELDS = %w[portal_id language category folder status approver page per_page].freeze
  INSERT_SOLUTION_ACTIONS = %w[index article_content].freeze

  ARTICLES_PRIVATE_CONTROLLER = 'ember/solutions/articles'.freeze

  SUMMARY_LIMIT = 3

  # [ TOKEN, STRING, STATUS_VALUE, TABLE_VALUE, ES_VALUE]
  STATUS_FILTER = [
    [:draft,     'solutions.status.draft',        1, 1, 4],
    [:published, 'solutions.status.published',    2, 2, 0],
    [:outdated, 'solutions.status.outdated',      3, 0, 0], # only used in article versions.
    [:in_review, 'solutions.status.in_review',    4, 1, 1],
    [:approved, 'solutions.status.approved',      5, 2, 2]
  ].freeze

  STATUS_FILTER_BY_KEY = Hash[*STATUS_FILTER.map { |i| [i[2], i[1]] }.flatten]
  STATUS_FILTER_BY_TOKEN = Hash[*STATUS_FILTER.map { |i| [i[0], i[2]] }.flatten]
  STATUS_VALUE_IN_TABLE_BY_KEY = Hash[*STATUS_FILTER.map { |i| [i[2], i[3]] }.flatten]
  STATUS_VALUE_IN_ES_BY_KEY = Hash[*STATUS_FILTER.map { |i| [i[2], i[4]] }.flatten]
  ICON_EXT = %w[.jpg .jpeg .jpe .png].freeze
  PLATFORM_TYPES = ['web', 'ios', 'android'].freeze
end
