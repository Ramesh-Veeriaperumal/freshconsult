class Tickets::UndoSendWorker < BaseWorker
  include Redis::UndoSendRedis
  sidekiq_options queue: :undo_send, retry: false

  def perform(args)
    note_schema_less_associated_attributes = args['note_schema_less_associated_attributes']
    user_id = args['user_id']
    attachment_list = args['attachment_details']
    inline_attachment_list = args['inline_attachment_details']
    account_id = args['account_id']
    ticket_id = args['ticket_id']
    publish_solution_later = args['publish_solution_later']
    note_basic_attributes = args['note_basic_attributes']
    created_at = note_basic_attributes['created_at']

    @ticket = Account.current.tickets.where(display_id: ticket_id).first

    return if @ticket.blank?

    undo_choice = get_undo_option(user_id, ticket_id, created_at)
    if undo_choice != UNDO_SEND_FALSE
      note = build_note(note_schema_less_associated_attributes, attachment_list,
                        inline_attachment_list, user_id,
                        ticket_id, created_at, note_basic_attributes)
      saved = note.save_note if note.present?
      send_newrelic_exception(account_id, user_id, ticket_id, created_at, StandardError.new('SaveError')) unless saved
      if publish_solution_later
        publish_solution(note.note_body.body_html, ticket_id, note.attachments)
      end
      delete_body_data(user_id, ticket_id, created_at)
    end
    delete_undo_choice(user_id, ticket_id, created_at)
  rescue Exception => e
    send_newrelic_exception(account_id, user_id, ticket_id, created_at, e)
    raise e
  ensure
    remove_undo_reply_enqueued(ticket_id)
  end

  def build_note(note_schema_less_associated_attributes, attachment_list,
                 inline_attachment_list, user_id,
                 ticket_id, created_at, note_basic_attributes)
    note = @ticket.notes.new(note_basic_attributes)
    note_schema_less_associated_attributes['created_at'] = nil
    note.assign_values(note_schema_less_associated_attributes)
    note.note_body_attributes = get_body_data(user_id, ticket_id, created_at)
    add_attachments(attachment_list, note)
    add_inline_attachments(inline_attachment_list, note)
    note
  end

  def add_attachments(attachment_list, note)
    return if attachment_list.blank?
    attachment_list.each do |att_id|
      attachment = Account.current.attachments.where(id: att_id).first
      note.attachments.push(attachment) if attachment
    end
  end

  def add_inline_attachments(inline_attachment_list, note)
    return if inline_attachment_list.blank?
    note.inline_attachment_ids = inline_attachment_list
  end

  def publish_solution(body_html, ticket_id, attachments)
    ticket = Account.current.tickets.where(id: ticket_id).first
    # title is set only for API if the ticket subject length is lesser than 3. from UI, it fails silently.
    title = if ticket.subject.length < 3
              t('undo_send_solution_error', ticket_display_id: ticket.display_id)
            else
              ticket.subject
            end
    Helpdesk::KbaseArticles
      .create_article_from_note(Account.current, user_id, title, body_html, attachments)
  end

  def send_newrelic_exception(account_id, user_id, ticket_id, created_at, exception)
    NewRelic::Agent.notice_error(exception,
                                 args: "#{account_id}:#{user_id}:#{ticket_id}:undosend:#{created_at}")
  end
end
