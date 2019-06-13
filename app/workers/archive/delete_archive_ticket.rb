module Archive
  class DeleteArchiveTicket < BaseWorker
    sidekiq_options queue: :delete_archive_ticket,
                    retry: 0,
                    failures: :exhausted

  
    def perform(args)
      args.symbolize_keys!
      @account = Account.current
      begin
        delete_archive_ticket args
        delete_archive_notes args if args[:note_ids].present?
      rescue Exception => e
        NewRelic::Agent.notice_error(e, description: 'Error occoured in deletion of archive ticket #{args[:ticket_id]} for account #{@account.id} from S3')
        raise e
      end  
    end  

    def delete_archive_ticket args
      s3_ticket_key = Helpdesk::S3::ArchiveTicket::Body.generate_file_path(@account.id, args[:ticket_id])
      AwsWrapper::S3.delete(S3_CONFIG[:archive_ticket_body], s3_ticket_key)
    end

    def delete_archive_notes args
      s3_note_keys = args[:note_ids].map do |note_id|
        Helpdesk::S3::ArchiveNote::Body.generate_file_path(@account.id, note_id)
      end
      AwsWrapper::S3.batch_delete(S3_CONFIG[:archive_note_body], s3_note_keys)
    end

  end
end