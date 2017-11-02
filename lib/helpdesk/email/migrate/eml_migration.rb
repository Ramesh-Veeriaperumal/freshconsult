require 'zip/zip'

module Helpdesk::Email::Migrate
  class EmlMigration
    attr_accessor :envelope_address, :notify_email, :tags_name, :custom_status, :skip_notification, :enable_outgoing, :file_path, :raise_error,
                  :account_id, :email_config_id

    MAX_UID = "99999999"

    def initialize(args={})
      initialise_attributes(args)
    end

    def initialise_attributes(attributes = {})
      attributes.each do |name, value|
        if respond_to?("#{name}=")
          send("#{name}=", value)
        end
      end
    end

    def process
      if mandatory_data_available?
        response = fetch_emails
      else
        mailbox_log "Provide all mandatory data in a Hash during initialize.  Mandatory : envelope_address, file_path, notify_email, account_id, email_config_id"
      end
      response
    end

    def mandatory_data_available?
      (file_path && envelope_address && notify_email && account_id && email_config_id)
    end

    def fetch_emails
      @mail_fetch_start_time = Time.zone.now
      @tickets_info = []
      Helpdesk::Email::Migrate::Mailer.send_mail(notify_email, "Migration started for zip file - #{file_path}")
      Zip::ZipFile.open(file_path) do |zip_file|
        zip_file.each do |file|
          begin
            file_name = file.name
            mailbox_log "Processing email from file : #{file_name}"
            email_content = file.get_input_stream.read
            args = {:raw_eml=>email_content,:tags_name=>tags_name,:envelope_address=>envelope_address,:custom_status=>custom_status,:notify_email=>notify_email,
                    :skip_notification=>skip_notification,:enable_outgoing=>enable_outgoing,:account_id=>account_id,:email_config_id=>email_config_id}
            response = Helpdesk::Email::Migrate::MailProcessor.new(args).process
            @tickets_info << "File Name-#{file_name} DisplayID-#{response[:display_id]} TicketID-#{response[:ticket_id]} NoteID-#{response[:note_id]}, "
          rescue Exception => e
            Rails.logger.debug "#{e}, #{e.message}, #{e.backtrace}"
            mailbox_log "Exceptions occurred during migration via zip file #{e}, #{e.message}, #{e.backtrace}"
            Helpdesk::Email::Migrate::Mailer.send_mail(notify_email, "Migration error. File Name - #{file_name} Zip File : #{file_path} 
                                                                             ERROR - #{e.class}, #{e.message}, #{e.backtrace}")
            raise e if raise_error # stop futher processing when error is occured
          end
        end
      end
      Helpdesk::Email::Migrate::Mailer.send_mail(notify_email, "Migration completed for Zip File - #{file_path} 
                                                Start_time - #{@mail_fetch_start_time} end_time - #{Time.now.utc} 
                                                Processed tickets info #{@tickets_info}")
    rescue Exception => e
      Rails.logger.debug "#{e}, #{e.backtrace}"
      mailbox_log "Exceptions occurred #{e}, #{e.backtrace}"
      Helpdesk::Email::Migrate::Mailer.send_mail(notify_email, "Migration stopped for zip_file path : #{file_path}, start_time - #{@mail_fetch_start_time}".squish!)
    end

    def mailbox_log msg
      puts "#{Time.now.utc} - #{Thread.current.object_id} - EmlMigration - #{msg} "
      Rails.logger.info "#{Time.now.utc} - #{Thread.current.object_id} - EmlMigration - #{msg} "
    end
  end
end