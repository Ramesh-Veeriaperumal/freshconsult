class Solution::ArticleVersion < ActiveRecord::Base
  include Redis::OthersRedis
  include Redis::RedisKeys
  
  self.primary_key = :id
  self.table_name = 'solution_article_versions'

  attr_accessible :meta, :live, :status

  # we are excluding title, and description while feature migration, we will directly get title and description from record itself
  # to avoid sending huge payload to sidekiq servers during migration
  attr_accessor :from_migration_worker, :triggered_from, :upsert_s3

  serialize :meta, Hash

  belongs_to_account
  belongs_to :user
  belongs_to :publisher,
             class_name: 'User',
             foreign_key: :published_by
  belongs_to :article,
             class_name: 'Solution::Article',
             inverse_of: :solution_article_versions

  scope :latest, ->{ order('created_at DESC, version_no DESC') }

  COMMON_ATTRIBUTES = %w[title description].freeze

  after_commit :store_version_in_s3, if: :content_changed?
  after_destroy :destroy_version_in_s3

  validates :title, presence: true, if: :validate_content?
  validates :description, presence: true, if: :validate_content?

  def content
    if @content.nil? # cache the content read from s3
      # for a new record s3 record won't be there and we don't need read from s3
      # for autosave and update case we will be always sending title and description. thus we don't need to do read and update. we can do upsert in with s3.update call itself.
      # if upsert_s3 is true, we expect all the attributes to be assigned that is present in content hash.
      @content = if new_record? || upsert_s3
                   {}
                 else
                   JSON.parse(AwsWrapper::S3.read(Solution::ArticleVersion.s3_bucket, Solution::ArticleVersion.content_path(article_id, id))).with_indifferent_access
                 end
    end
    @content
  end

  # methods to track s3 content changes
  def content_changed!
    @content_changed = true
  end

  def content_not_changed!
    @content_changed = false
  end

  def discarded?
    self.status == Solution::Article::STATUS_KEYS_BY_TOKEN[:discarded]
  end

  def published?
    self.status == Solution::Article::STATUS_KEYS_BY_TOKEN[:published]
  end

  def discard!
    meta[:discarded_by] = User.current.id
    self.status = Solution::Article::STATUS_KEYS_BY_TOKEN[:discarded]
    save
  end

  def discarded_by
    meta[:discarded_by]
  end

  def restore(version_no)
    meta[:restored_version] = version_no
  end

  def unlive!
    self.live = false
    save
  end

  def content_changed?
    @content_changed
  end

  # the model is changed even if there is any changes in title and description also
  # rails won't trigger update and callbacks if there is no attribute changes
  def changed?
    @content_changed || super
  end

  def title
    content[:title]
  end

  def title=(val)
    content_changed! unless val == title
    content[:title] = val
  end

  def description
    content[:description]
  end

  def description=(val)
    content_changed! unless val == description
    content[:description] = val
  end

  def s3_payload(action)
    {
      id: id,
      article_id: article_id,
      action: action,
      triggered_from: triggered_from
    }
  end

  def self.s3_bucket
    S3_CONFIG[:article_versioning_bucket]
  end

  def self.content_path(article_id, id)
    format(%(data/helpdesk/article_versions/#{Rails.env}/%{account_id}/%{article_id}/%{id}.json), account_id: Account.current.id, article_id: article_id, id: id)
  end

  def store_version_in_s3
    payload = s3_payload('store')
    unless from_migration_worker
      payload[:title] = title
      payload[:description] = description
    end
    job_id = Solution::ArticleVersionsWorker.perform_async(payload)
    Rails.logger.info "AVW:: Enqeue store [#{account_id},#{article_id},#{job_id}]"
    content_not_changed!
  end

  def destroy_version_in_s3
    job_id = Solution::ArticleVersionsWorker.perform_async(s3_payload('destroy'))
    Rails.logger.info "AVW:: delete [#{account_id},#{article_id},#{id},#{job_id}]"
    content_not_changed!
  end

  def update_attachments_info
    normal_attachments = article.attachments
    cloud_files = article.cloud_files
    draft = article.draft


    # to handle draft attachment changes, draft should be present,
    # and the version should not be created from article migration script, for draft migration script we can handle as usual

    if draft && !(from_migration_worker && triggered_from == 'article')
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

  # we don't need to validate if there is no changes in title, description for existing records.this will reduce a call to s3
  def validate_content?
    new_record? || content_changed?
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
