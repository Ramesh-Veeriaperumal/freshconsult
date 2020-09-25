['note_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
# ['note_test_helper.rb', 'freshcaller_call_test_helper.rb', 'twitter_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
# ['facebook_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }

module NotesTestHelper
  include NoteTestHelper
  include Facebook::TicketActions::Util
  # include FreshcallerCallTestHelper
  # include TwitterTestHelper
  # include FacebookTestHelper
  # include Facebook::Constants

  # ASSOCIATION_REFS_BASED_ON_TYPE = ["tweet", "fb_post"]

  def note_params_hash(params = {})
    body = params[:body_html] || Faker::Lorem.paragraph
    { 
      :note_body_attributes => { :body_html => body}, 
      :source => params[:source] || Account.current.helpdesk_sources.note_source_keys_by_token["note"],
      :category => params[:category],
      :private => params[:private],
      :incoming => params[:incoming],
      :notable_id => params[:ticket_id] || Account.current.tickets.last.id
     }
  end

  def central_publish_note_pattern(expected_output = {}, note)
    category = note.category
    source = note.source
    ret_hash = {
      id: note.id,
      account_id: note.account_id,
      category: { id: category, name: Helpdesk::Note::CATEGORIES_NAMES_BY_KEY[category].to_s },
      source: { id: source, name: Account.current.helpdesk_sources.note_source_names_by_key[source] },
      incoming: note.incoming,
      private: note.private,
      deleted: note.deleted,
      archive: note.notable.archive,
      email_config_id: note.email_config_id,
      header_info: note.header_info,
      response_time_in_seconds: note.response_time_in_seconds,
      response_time_by_bhrs: note.response_time_by_bhrs,
      last_modified_user_id: note.last_modified_user_id,
      to_email_user_ids: Account.current.user_emails.where(email: note.to_emails).pluck(:user_id),
      last_modified_timestamp: note.last_modified_timestamp.try(:utc).try(:iso8601),
      created_at: note.created_at.try(:utc).try(:iso8601),
      updated_at: note.updated_at.try(:utc).try(:iso8601),

      from_email: note.from_email,
      to_emails: note.to_emails,
      cc_emails: note.cc_emails,
      bcc_emails: note.bcc_emails,
      body: note.body,
      body_html: note.body_html,
      full_text: note.full_text,
      full_text_html: note.full_text_html,

      attachment_ids: note.attachments.map(&:id),
      user_id: note.user_id,
      notable_id: note.notable.display_id,
      notable_type: note.notable_type,
      source_additional_info: source_additional_info_hash(note),
      kind: note.kind
    }
    ret_hash["feedback_id"] = note.survey_result_assoc.id if note.feedback?
    ret_hash[:response_violated] = note.response_violated if Account.current.next_response_sla_enabled?
    # ASSOCIATION_REFS_BASED_ON_TYPE.each do |ref|
    #   ret_hash["#{ref}_id".to_sym] = note.safe_send(ref).id if note.safe_send(ref)
    # end 

    # ret_hash["freshfone_call_id"] = note.freshfone_call.id if note.freshfone_call.present?
    # ret_hash["freshcall_call_id"] = note.freshcaller_call.id if note.freshcaller_call.present?
    ret_hash
  end

  def event_info(event)
    { pod: ChannelFrameworkConfig['pod'], hypertrail_version: CentralConstants::HYPERTRAIL_VERSION }
  end

  def central_assoc_note_pattern(expected_output = {}, note)
    ret_hash = {
      notable: Hash,
      user: Hash,
      attachments: Array
    }
    ret_hash["feedback"] = feedback_hash(note) if note.feedback?
    # ret_hash["fb_post"] = fb_post_hash(note) if note.fb_post.present?
    # ret_hash["freshfone_call"] = Hash if note.freshfone_call.present?
    # ret_hash["freshcaller_call"] = freshcaller_call_hash(note) if note.freshcaller_call.present?
    ret_hash
  end

  def source_additional_info_hash(note)
    source_info = {}
    source_info[:email] = email_source_info(note.schema_less_note.note_properties) if email_note?(note.source)
    tweet = note.tweet

    if tweet.present?
      twitter_handle = tweet.twitter_handle
      latest_tweet_info = latest_tweet(note)
      source_info[:twitter] = {
        tweet_id: tweet.tweet_id.to_s,
        type: tweet.tweet_type,
        support_handle_id: twitter_handle.present? ? twitter_handle.twitter_user_id.to_s : nil,
        support_screen_name:  twitter_handle.present? ? twitter_handle.screen_name : nil,
        requester_screen_name: tweet.tweetable.user.twitter_id,
        twitter_handle_id: twitter_handle.present? ? twitter_handle.id : nil,
        stream_id: tweet.stream_id,
        latest_tweet_id: latest_tweet_info[:latest_tweet_id],
        latest_tweet_stream_id: latest_tweet_info[:latest_tweet_stream_id]
      }
    end

    if note.fb_note?
      fb_post = note.fb_post
      fb_page = (fb_post.present? ? fb_post.facebook_page : note.notable.fb_post.try(:facebook_page))

      source_info[:facebook] = basic_details(fb_post, note).merge(fb_page_details(fb_page, note))

    end
    source_info.presence
  end

  def email_note?(source)
    [Account.current.helpdesk_sources.note_source_keys_by_token['email'],
     Account.current.helpdesk_sources.note_source_keys_by_token['note']].include?(source)
  end

  def fb_page_details(fb_page, note)
    {
      support_fb_page_id: fb_page.try(:page_id).try(:to_s),
      support_fb_page_name: fb_page.try(:page_name),
      fb_page_db_id: fb_page.try(:id).try(:to_s),
      fb_handler_id: fetch_handler_id(fb_page, note)
    }
  end

  def basic_details(fb_post, note)
    {
      fb_item_id: fb_post.try(:post_id).to_s,
      type: fb_post.try(:msg_type),
      requester_profile_id: note.requester_fb_id.to_s
    }
  end

  def fetch_handler_id(fb_page, note)
    return nil if fb_page.nil?
    parent_post_id = note.try(:fb_post).try(:parent).try(:post_id)
    handler_key = if note.notable.is_fb_message?
                    get_thread_key(fb_page, note.notable.fb_post)
                  elsif parent_post_id
                    parent_post_id
                  else
                    note.notable.fb_post.original_post_id
                  end
    handler_key
  end

  # def freshcaller_call_hash(note)
  #   call = note.freshcaller_call
  #   ret_hash = {
  #     id: call.id,
  #     fc_call_id: call.fc_call_id,
  #     recording_status: {
  #       id: call.recording_status,
  #       name: Freshcaller::Call::RECORDING_STATUS_NAMES_BY_KEY[call.recording_status]
  #     }
  #   }
  # end

  # def fb_post_hash(note)
  #   fb_post = note.fb_post
  #   ret_hash = {
  #     "id": fb_post.id,
  #     "post_id": fb_post.post_id,
  #     "msg_type": fb_post.msg_type,
  #     "page": {
  #       "name": fb_post.facebook_page.page_name,
  #       "page_id": fb_post.facebook_page.page_id
  #     }
  #   }
  # end

  def feedback_hash(note)
    survey_result_assoc = note.survey_result_assoc
    survey_rating = survey_result_assoc.class == SurveyResult ? survey_result_assoc.rating : survey_result_assoc.custom_rating
    ret_hash = {
      "id": survey_result_assoc.id,
      "rating": survey_rating,
      "agent_id": survey_result_assoc.agent_id,
      "group_id": survey_result_assoc.group_id,
      "survey_id": survey_result_assoc.survey_id
    }
  end

  def latest_tweet(note)
    latest_tweet_info = {}
    twitter_notes = note.notable.notes.latest_twitter_comment
    if twitter_notes.present?
      lasest_note = twitter_notes.first
      if lasest_note.tweet.present?
        latest_tweet_info[:latest_tweet_id] = lasest_note.tweet.tweet_id
        latest_tweet_info[:latest_tweet_stream_id] = lasest_note.tweet.stream_id
      end
    end
    latest_tweet_info
  end
end
