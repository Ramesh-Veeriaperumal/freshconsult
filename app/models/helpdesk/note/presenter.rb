class Helpdesk::Note < ActiveRecord::Base
  include RepresentationHelper
  include TicketsNotesHelper
  include Facebook::TicketActions::Util

  DATETIME_FIELDS = ["last_modified_timestamp", "created_at", "updated_at"]
  BODY_HASH_FIELDS = ["body", "body_html", "full_text", "full_text_html"]
  EMAIL_FIELDS = ["from_email", "to_emails", "cc_emails", "bcc_emails"]
  # ASSOCIATION_REFS_BASED_ON_TYPE = ["tweet", "fb_post"]
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
    t.add :response_violated, :if => proc { Account.current.next_response_sla_enabled? }
    t.add :last_modified_user_id
    t.add proc { |x| x.account.user_emails.where(email: x.parsed_to_emails).pluck(:user_id) }, as: :to_email_user_ids
    DATETIME_FIELDS.each do |key|
      t.add proc { |x| x.utc_format(x.safe_send(key)) }, as: key
    end
    (EMAIL_FIELDS + BODY_HASH_FIELDS).each do |key|
      t.add proc { |x| x.safe_send(key) }, as: key
    end

    #association_ids
    t.add :notable_display_id, as: :notable_id
    t.add :notable_type
    t.add :user_id
    t.add proc { |x| x.attachments.map(&:id) }, as: :attachment_ids
    t.add proc { |x| x.survey_result_assoc.id }, as: :feedback_id, :if => proc { |x| x.feedback? }

    # Source additional info
    t.add :source_additional_info_hash, as: :source_additional_info

    # the custom sources i.e. tweet, fb, others are custom sources and will be revisited.
    # (ASSOCIATION_REFS_BASED_ON_TYPE).each do |key|
    #   t.add proc { |x| x.safe_send(key).id }, as: "#{key}_id".to_sym, :if => proc { |x| x.safe_send(key) }
    # end
    # t.add proc { |x| x.freshcaller_call.id }, as: :freshcaller_call_id, :if => proc { |x| x.freshcaller_call.present?}
    t.add :kind
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
      name: Account.current.helpdesk_sources.note_source_names_by_key[source]
    }
  end

  def survey_result_assoc
    @survey_result_assoc ||= (survey_remark || custom_survey_remark).survey_result
  end

  def requester_twitter_id
    user.try(:twitter_id)
  end

  def requester_fb_id
    user.try(:fb_profile_id)
  end

  def source_additional_info_hash
    source_info = {}
    source_info = social_source_additional_info(source_info)
    source_info[:email] = email_source_info(schema_less_note.note_properties) if email_note?
    source_info.presence
  end

  # associations
  api_accessible :central_publish_associations do |t|
    t.add :notable, template: :central_publish
    t.add :user, template: :central_publish
    t.add :attachments, template: :central_publish
    t.add :feedback_hash, as: :feedback, if: proc{ |x| x.feedback? }
    # t.add :freshcaller_call, template: :central_publish, if: proc { |x| x.freshcaller_call.present? }
    # t.add :tweet_hash, as: :tweet, if: proc { |x| x.tweet.present? }
    # t.add :fb_post_hash, as: :fb_post, if: proc{ |x| x.fb_post.present? }
  end

  api_accessible :central_publish_destroy do |t|
    t.add :id
    t.add :notable_display_id, as: :notable_id
    t.add :notable_type
    t.add :account_id
  end

  # Internal methods used by presenter.
  def notable_display_id
    case notable_type
      when 'Helpdesk::Ticket'
          notable.display_id
      when 'Helpdesk::ArchiveTicket'
        Helpdesk::ArchiveTicket.unscoped { notable.display_id }
    end
  end

  def feedback_hash
    survey_rating = survey_result_assoc.class == SurveyResult ? survey_result_assoc.rating : survey_result_assoc.custom_rating
    {
      "id": survey_result_assoc.id,
      "rating": survey_rating,
      "agent_id": survey_result_assoc.agent_id,
      "group_id": survey_result_assoc.group_id,
      "survey_id": survey_result_assoc.survey_id
    }
  end

  # def fb_post_hash
  #   {
  #     "id": fb_post.id,
  #     "post_id": fb_post.post_id,
  #     "msg_type": fb_post.msg_type,
  #     "page": {
  #       "name": fb_post.facebook_page.page_name,
  #       "page_id": fb_post.facebook_page.page_id
  #     }
  #   }
  # end

  def central_payload_type
    if import_note
      action = [:create].find{ |action| transaction_include_action? action }
      "import_note_#{action}" if action.present?
    end
  end

  def relationship_with_account
    'notes'
  end


  # ************************************
  # METHOS USED BY CENTRAL PUBLISHER GEM.
  # ************************************

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
    @note_central_changes ||= [*note_body.previous_changes.keys, *(@model_changes || {}).keys.map(&:to_s)]
    @note_central_changes.include?(field)
  end

  def event_info(_event)
    activity_hash = construct_activity_hash
    { pod: ChannelFrameworkConfig['pod'], hypertrail_version: CentralConstants::HYPERTRAIL_VERSION, app_update: !@manual_central_publish }.merge(activity_hash)
  end

  def parsed_to_emails
    return if to_emails.blank?

    begin
      to_emails.map do |email|
        encoded = Mail::Encodings.address_encode(email)
        Mail::Address.new(encoded).address
      end
    rescue StandardError => e
      Rails.logger.error "Error in to_email parse of Note central publish :: #{e.message} :: #{e.backtrace}"
    end
  end

  def construct_activity_hash
    activity_type && activity_type[:type] == Social::Constants::TWITTER_FEED_NOTE ? twitter_feed_note_activity_hash(activity_type) : {}
  end

  def twitter_feed_note_activity_hash(activity_type)
    {
      activity_type: activity_type
    }
  end
end
