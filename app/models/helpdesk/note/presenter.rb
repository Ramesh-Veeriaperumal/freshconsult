class Helpdesk::Note < ActiveRecord::Base
  include RepresentationHelper
  DATETIME_FIELDS = ["last_modified_timestamp", "created_at", "updated_at"]
  BODY_HASH_FIELDS = ["body", "body_html", "full_text", "full_text_html"]
  EMAIL_FIELDS = ["from_email", "to_emails", "cc_emails", "bcc_emails"]
  ASSOCIATION_REFS_BASED_ON_TYPE = ["feedback", "tweet", "fb_post"]
  DONT_CARE_FIELDS = ["body", "full_text"]
  DONT_CARE_VALUE = '*'.freeze

  acts_as_api

  api_accessible :central_publish do |t|
    t.add :id
    t.add :account_id
    t.add :category_hash, as: :category
    t.add :source_hash, as: :source
    t.add :incoming
    t.add :private
    t.add :deleted
    t.add proc { |x| x.notable_type == "Helpdesk::ArchiveTicket" }, as: :archive
    t.add :email_config_id
    t.add :header_info
    t.add :response_time_in_seconds
    t.add :response_time_by_bhrs
    t.add :last_modified_user_id
    DATETIME_FIELDS.each do |key|
      t.add proc { |x| x.utc_format(x.safe_send(key)) }, as: key
    end
    (EMAIL_FIELDS + BODY_HASH_FIELDS).each do |key|
      t.add proc { |x| x.safe_send(key) }, as: key
    end
    (ASSOCIATION_REFS_BASED_ON_TYPE).each do |key|
      t.add proc { |x| x.safe_send(key).id }, as: "#{key}_id".to_sym, :if => proc { |x| x.safe_send(key) }
    end
    t.add :user_id
    t.add :ticket_id
    t.add proc { |x| x.attachments.map(&:id) }, as: :attachment_ids
  end

  def category_hash
    {
      id: category,
      name: CATEGORIES_NAMES_BY_KEY[category].to_s
    }
  end

  def source_hash
    { 
      id: source,
      name: SOURCE_NAMES_BY_KEY[source]
    }
  end

  api_accessible :central_publish_associations do |t|
    t.add proc { |x| x.notable }, as: :ticket, template: :central_publish
    t.add :user, template: :central_publish
    t.add :attachments, template: :central_publish
    t.add :tweet_hash, if: proc { |x| x.tweet.present? }
    t.add :fb_post_hash, if: proc{ |x| x.fb_post.present? }
    t.add :feedback_hash, if: proc{ |x| x.survey_remark.present? || x.custom_survey_remark.present? }
  end

  api_accessible :central_publish_destroy do |t|
    t.add :id
    t.add :ticket_id
    t.add :account_id
  end

  def tweet_hash
    twitter_handle = tweet.twitter_handle
    {
      "id": tweet.id,
      "tweet_id": tweet.tweet_id,
      "type": tweet.type,
      "twitter_handle": {
        "id": twitter_handle.id,
        "state": {
          "constant": twitter_handle.constant,
          "name": Social::TwitterHandle::TWITTER_NAMES_BY_STATE_KEYS[twitter_handle.constant]
        }
      },
      "stream_id": tweet.stream_id
    }
  end

  def fb_post_hash
    {
      "id": fb_post.id,
      "post_id": fb_post.post_id,
      "msg_type": fb_post.msg_type,
      "page": {
        "name": fb_post.facebook_page.page_name,
        "page_id": fb_post.facebook_page.page_id
      }
    }
  end

  # Has to be taken later as the relation is quite different.
  # def freshcaller_hash
  #   freshcaller_assoc = freshcaller_call || freshfone_call
  #   recording_status = freshcaller_assoc.recording_status
  #   {
  #     "id": freshcaller_assoc.id,
  #     "fc_call_id": freshcaller_assoc.fc_call_id,
  #     "recording_status": {
  #       "id": recording_status,
  #       "name": Freshcaller::CALL::RECORDING_STATUS_NAMES_BY_KEY[recording_status]
  #     }
  #   }
  # end

  def feeback_hash
    survey_remark_assoc = survey_remark || custom_survey_remark
    survey_result_assoc = survey_remark_assoc.survey_result
    survey_assoc = survey_remark_assoc.survey
    {
      "id": survey_result_assoc.id,
      "rating": survey_result_assoc.rating,
      "survey": {
        "id": survey_assoc.id,
        "title": survey_assoc.title,
        "active": survey_assoc.active,
        "default": survey_assoc.default,
        "deleted": survey_assoc.deleted,

      }
    }
  end

  def ticket_id
    belongs_to_ticket? ? notable.display_id : Helpdesk::ArchiveTicket.unscoped { notable.display_id }
  end

  def belongs_to_ticket?
    notable_type == 'Helpdesk::Ticket'
  end

  def belongs_to_archive_ticket?
    notable_type == 'Helpdesk::ArchiveTicket'
  end

  # ************************************
  # METHOS USED BY CENTRAL PUBLISHER GEM.
  # ************************************

  def self.central_publish_enabled?
    Account.current.note_central_publish_enabled?
  end

  def central_publish_worker_class
    "CentralPublishWorker::#{Account.current.subscription.state.titleize}NoteWorker"
  end

  def model_changes_for_central
    model_changes = @model_changes || self.changes.try(:to_hash) || @manual_publish_changes
    DONT_CARE_FIELDS.each do |field|
      model_changes[field.to_sym] = [nil, DONT_CARE_VALUE] if  content_changed?(field)
      model_changes["#{field}_html".to_sym] = [nil, DONT_CARE_VALUE] if content_changed?("#{field}_html")
    end
    model_changes
  end

  def content_changed?(field)
    @note_central_changes ||= [*note_old_body.previous_changes.keys, *(@model_changes || {}).keys.map(&:to_s)]
    @note_central_changes.include?(field)
  end
end
