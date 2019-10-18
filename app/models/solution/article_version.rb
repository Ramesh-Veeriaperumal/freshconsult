class Solution::ArticleVersion < ActiveRecord::Base
  include Redis::OthersRedis
  include Redis::RedisKeys
  
  self.primary_key = :id
  self.table_name = 'solution_article_versions'

  attr_accessible :meta, :live

  # we are excluding title, and description while feature migration, we will directly get title and description from record itself
  # to avoid sending huge payload to sidekiq servers during migration
  attr_accessor :exclude_article_payload, :triggered_from

  serialize :meta, Hash

  belongs_to_account
  belongs_to :user
  belongs_to :publisher,
             class_name: 'User',
             foreign_key: :published_by
  belongs_to :article,
             class_name: 'Solution::Article',
             inverse_of: :solution_article_versions

  scope :latest, order: 'created_at DESC, version_no DESC'

  COMMON_ATTRIBUTES = %w[title description].freeze

  def discard!
    meta[:discarded] = true
    save
  end

  def unlive!
    self.live = false
    save
  end

  def title=(val)
    title = val
  end

  def description=(val)
    description = val
  end

  def update_attachments_info
    normal_attachments = article.attachments
    cloud_files = article.cloud_files
    draft = article.draft
    if draft
      normal_attachments = remove_deleted_attachments(draft, normal_attachments + draft.attachments, :attachments)
      cloud_files = remove_deleted_attachments(draft, cloud_files + draft.cloud_files, :cloud_files)
    end

    meta[:attachments] = normal_attachments.map do |attachment|
      {
        id: attachment.id,
        name: attachment.content_file_name,
        content_type: attachment.content_content_type
      }
    end

    meta[:cloud_files] = cloud_files.map do |attachment|
      {
        id: attachment.id,
        name: attachment.filename,
        url: attachment.url,
        application_id: attachment.application.id,
        application_name: attachment.application.name
      }
    end
  end

  def session_key
    ARTICLE_VERSION_SESSION % { account_id: account_id, article_id: article_id, version_id: id }
  end

  def session
    get_others_redis_key(session_key)
  end

  def set_session(value)
    set_others_redis_key(session_key, value)
    value
  end

  private

    def remove_deleted_attachments(draft, attachments, type)
      if draft.meta.present? && draft.meta[:deleted_attachments].present? && draft.meta[:deleted_attachments][type].present?
        deleted_att_ids = draft.meta[:deleted_attachments][type]
        attachments = attachments.reject { |a| deleted_att_ids.include?(a.id) }
      end
      attachments
    end

end
