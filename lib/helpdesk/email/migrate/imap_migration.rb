#args = {:user_name=>"user@gmail.com", :password=>"password", :notify_email=>"notify@gmail.com", :envelope_address=>"envelope@local.freshdesk.com", :server_name=>"imap.gmail.com", :folder=>"INBOX", :tags_name=>["email_import","custom2"], :gmail_tags=>false, :start_time=>"DD-MMM-YYYY HH-MM-SS +0000", :end_time=>"DD-MMM-YYYY HH-MM-SS +0000"}
#Helpdesk::Email::EmailMigration.new(args)

require 'net/imap'
require 'timeout'
require 'date'

module Helpdesk::Email::Migrate
  class ImapMigration
    attr_accessor :user_name, :password, :notify_email, :server_name, :start_uid, :end_uid, :start_date, :end_date, :from_address, :to_address, 
                  :uid_array, :subject, :envelope_address, :port, :ssl, :authentication, :folder, :gmail_tags, :tags_name, :uid_list, 
                  :custom_status, :skip_notification, :start_time, :end_time, :imap, :enable_outgoing, :raise_error, :account_id, :email_config_id 

    MAX_UID = "99999999"

    def initialize(args={})
      initialise_attributes(args)
      self.port        = self.port.present? ? self.port : 993
      self.ssl         = self.ssl.nil? ? true : self.ssl
      self.folder      = self.folder.nil? ? "INBOX" : self.folder
      self.gmail_tags  = self.gmail_tags.nil? ? false : self.gmail_tags
      parse_time
      connect_imap_server
    end

    def initialise_attributes(attributes = {})
      attributes.each do |name, value|
        if respond_to?("#{name}=")
          safe_send("#{name}=", value)
        end
      end
    end

    def parse_time
      mailbox_log "Sample start_time/end_time DD-MMM-YYYY HH:MM:SS +0000"
      if start_time.present?
        date = DateTime.strptime(self.start_time, '%d-%b-%Y %H:%M:%S %z') 
        self.start_date = date.strftime("%d-%b-%Y")
      end 
      if end_time.present? 
        date = DateTime.strptime(self.end_time, '%d-%b-%Y %H:%M:%S %z') + 1  #end date will be one day after than end_time
        self.end_date = date.strftime("%d-%b-%Y")
      end
    end 

    def connect_imap_server
      Timeout.timeout(15) do
        self.imap = Net::IMAP.new(server_name, port, ssl)
        unless authentication
          imap.login(user_name, password)
        else
          imap.authenticate(authentication, user_name, password)
        end
        imap.examine(folder)
        mailbox_log "Successfully Logged in customer mailbox"
      end
    rescue => e
      mailbox_log "Error occurred While logining customer mailbox #{e.class}, #{e.message}, #{e.backtrace}"
      raise e
    end

    def process
      if mandatory_data_available?
        response = convert_emails_to_tickets
      else
        mailbox_log "Provide all mandatory data in a Hash during initialize.  Mandatory : envelope_address, user_name, password, notify_email, 
                     account_id, email_config_id, server_name.  Optional : start_uid, end_uid, start_date, port, ssl, authentication"
      end
      response
    end

    def mandatory_data_available?
      (server_name && envelope_address && user_name && password && notify_email && account_id && email_config_id)
    end

    def convert_emails_to_tickets
      start_time = Time.zone.now

      @mail_fetch_start_time = Time.zone.now
      @tickets_info = []
      Helpdesk::Email::Migrate::Mailer.send_mail(notify_email, "Migration started for folder - #{folder}, email address : #{user_name}")
      fetch_email_through_imap if imap.present?
      Helpdesk::Email::Migrate::Mailer.send_mail(notify_email, "Migration completed for folder #{folder}. Failed uids - #{@failed_uids.inspect}
                                                Start_time - #{@mail_fetch_start_time} end_time - #{Time.zone.now}. Processed tickets info #{@tickets_info}")
    end

    def fetch_email_through_imap
      begin
        @failed_uids = []
        @latest_uid = nil
        @uids_processed = []
        thread_ids = []
        uids = uids_list
        if imap.nil?
          mailbox_log "Imap connection is not available"
          return 0
        end
        mailbox_log "Start proccessing message for uids : #{uids.inspect} "
        uids.each_with_index do |uid, i|
          break unless uid
          begin
            mailbox_log "Processing folder : #{folder} UID : #{uid}"
            @latest_uid = uid
            next if @uids_processed.include? uid
            if (i%100 == 0)
              unless imap.disconnected?
                imap.logout
                imap.disconnect
              end
              sleep(5)
              connect_imap_server
            end
            args = {:imap=>imap,:uid=>uid,:tags_name=>tags_name,:gmail_tags=>gmail_tags,:envelope_address=>envelope_address, :notify_email=>notify_email,
                    :custom_status=>custom_status, :skip_notification=>skip_notification,:enable_outgoing=>enable_outgoing,:account_id=>account_id, :email_config_id=>email_config_id}
            response = Helpdesk::Email::Migrate::MailProcessor.new(args).process
            @uids_processed << uid if uid.present?
            @tickets_info << "UID-#{uid} DisplayID-#{response[:display_id]} TicketID-#{response[:ticket_id]} NoteID-#{response[:note_id]}, "
          rescue Exception => e
            Rails.logger.debug "#{e}, #{e.backtrace}"
            mailbox_log "Exceptions occurred during migration via imap #{e}, #{e.backtrace}"
            Helpdesk::Email::Migrate::Mailer.send_mail(notify_email, "Migration error. UID - #{@latest_uid} Folder - #{folder} ERROR - #{e.class}, #{e.message}, #{e.backtrace}")
            @failed_uids.push uid
            unless imap.disconnected?
              imap.logout
              imap.disconnect
            end
            sleep(60)
            raise e if raise_error # stop futher processing when error is occured
            connect_imap_server
          end
        end
      rescue Exception => e
        Rails.logger.debug "#{e}, #{e.backtrace}"
        mailbox_log "Exceptions occurred #{e}, #{e.backtrace}"
        Helpdesk::Email::Migrate::Mailer.send_mail(notify_email, "Migration stopped for folder #{folder}.
                                                   Latest UID #{@latest_uid} Failed uids - #{@failed_uids.inspect}
                                                   start_time - #{@mail_fetch_start_time}".squish!)
        return
      ensure
        imap.logout
      end
    end

    def uids_list
      if uid_array.present?
        mailbox_log "Uid list is been provided by customer -- #{uid_array.join(", ")}"
        return uid_array 
      end
      uid_search_arr = []
      uid_search_arr += ["FROM", from_address] if from_address
      uid_search_arr += ["TO", to_address] if to_address
      uid_search_arr += ["SINCE", start_date] if start_date
      uid_search_arr += ["BEFORE", end_date] if end_date
      uid_search_arr += ["SUBJECT", subject] if subject
      uid_search_arr += ["UID", "#{start_uid}:#{end_uid}"] if start_uid && end_uid
      uid_search_arr += ["UID", "1:#{MAX_UID}"] unless uid_search_arr.present?
      mailbox_log "uid search array : #{uid_search_arr.join(", ")}"
      uid_arr = imap.uid_search(uid_search_arr)
      mailbox_log "uid_arr : #{uid_arr.join(", ")}"
      valid_uids = []
      if start_time.present? && end_time.present?
        start_datetime = DateTime.parse(start_time)
        end_datetime = DateTime.parse(end_time)
        mailbox_log "start_datetime : #{start_datetime}, end_datetime : #{end_datetime}"
        uid_arr.each do |uid|
          uid_datetime =  DateTime.parse(internal_date(uid))
          mailbox_log "uid : #{uid}, datetime : #{uid_datetime}"
          valid_uids << uid if ((start_datetime <= uid_datetime) && (end_datetime >= uid_datetime)) 
        end
        uid_arr = valid_uids
      end
      mailbox_log "Valid Uids list from #{start_time} to #{end_time} : #{uid_arr.join(", ")}"
      uid_arr
    end

    def internal_date(uid)
      imap.uid_fetch(uid, "INTERNALDATE")[0].attr["INTERNALDATE"]
    end

    def mailbox_log msg
      Rails.logger.info "#{Time.now.utc} - #{Thread.current.object_id} - ImapMigration - #{msg} "
    end
  end
end
