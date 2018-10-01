['note_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }

module NotesTestHelper
  include NoteTestHelper
  ASSOCIATION_REFS_BASED_ON_TYPE = ["feedback", "tweet", "fb_post", "freshcaller"]

  def note_params_hash(params = {})
    body = params[:body_html] || Faker::Lorem.paragraph
    { 
      :note_body_attributes => { :body_html => body}, 
      :source => params[:source] || Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["note"],
      :category => params[:category],
      :private => params[:private],
      :incoming => params[:incoming],
      :notable_id => params[:ticket_id] || Helpdesk::Ticket.last.display_id,
     }
  end

  def central_publish_note_pattern(expected_output = {}, note)
    category = note.category
    source = note.source
    ret_hash = {
      id: note.id,
      account_id: note.account_id,
      category: { id: category, name: Helpdesk::Note::CATEGORIES_NAMES_BY_KEY[category].to_s },
      source: { id: source, name: Helpdesk::Note::SOURCE_NAMES_BY_KEY[source] },
      incoming: note.incoming,
      private: note.private,
      deleted: note.deleted,
      archive: note.notable.archive,
      email_config_id: note.email_config_id,
      header_info: note.header_info,
      response_time_in_seconds: note.response_time_in_seconds,
      response_time_by_bhrs: note.response_time_by_bhrs,
      last_modified_user_id: note.last_modified_user_id,
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
      ticket_id: note.notable.display_id
    }
    ASSOCIATION_REFS_BASED_ON_TYPE.each do |ref|
      ret_hash["#{ref}_id".to_sym] = note.safe_send(refs).id if note.safe_send(ref)
    end 
    ret_hash
  end

  def central_assoc_note_pattern(expected_output = {}, note)
    ret_hash = {
      ticket: Hash,
      user: Hash,
      attachments: Array
    }
    ASSOCIATION_REFS_BASED_ON_TYPE.each do |ref|
      ret_hash[ref.to_sym] = Hash if note.safe_send(ref) 
    end
    ret_hash
  end

end