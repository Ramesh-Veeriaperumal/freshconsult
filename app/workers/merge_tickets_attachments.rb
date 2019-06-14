class MergeTicketsAttachments < BaseWorker
  sidekiq_options :queue => :merge_tickets_attachments, :retry => 0, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    account = Account.current
    source_ticket = account.tickets.find_by_id(args[:source_ticket_id])
    target_ticket = account.tickets.find_by_id(args[:target_ticket_id])
    source_description_note = target_ticket.notes.find_by_id(args[:source_description_note_id])
    return if source_ticket.blank? || source_description_note.blank?
    source_ticket.all_attachments.each do |attachment|
      source_description_note.attachments.build(content: attachment.to_io, description: '', account_id: account)
    end
    source_ticket.cloud_files.each do |cloud_file|
      source_description_note.cloud_files.build(url: cloud_file.url, application_id: cloud_file.application_id, filename: cloud_file.filename)
    end
    source_ticket.inline_attachments.update_all(attachable_type: 'Note::Inline', attachable_id: source_description_note.id)
    source_description_note.save_note
  end
end