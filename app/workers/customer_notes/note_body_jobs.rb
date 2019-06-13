class CustomerNotes::NoteBodyJobs < BaseWorker
  sidekiq_options :queue => :customer_note_body_queue, :retry => 4, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    @account = Account.current
    args[:account_id] = @account.id
    note = nil
    if args[:create] || args[:update]
      note = customer_note(args[:key_id], args[:type])
      args[:data] = { body: note.body }
    end
    Helpdesk::S3::CustomerNote::Body.push_to_s3(args, S3_CONFIG[bucket_name(args[:type])])
    note.populate_s3_key if note
  rescue StandardError => e
    Rails.logger.debug "Exception #{e.message}"
    NewRelic::Agent.notice_error(
      e,
      description: "error occured while pushing note body of #{args[:key_id]} of type #{args[:type]} to s3"
    )
  end

  private

    def scoper(type)
      type.to_sym == :contact_note ? @account.contact_notes : @account.company_notes
    end

    def bucket_name(type)
      type.to_sym == :contact_note ? :contact_note_body : :company_note_body
    end

    def customer_note(note_id, type)
      scoper(type).find_by_id(note_id)
    end
end
