#args = {:user_name=>"user@gmail.com", :password=>"password", :notify_email=>"notify@gmail.com", :envelope_address=>"envelope@local.freshdesk.com", :server_name=>"imap.gmail.com", :folder=>"INBOX", :tags_name=>"email_import", :gmail_tags=false}
#Helpdesk::Email::EmailMigration.new(args)

require 'net/imap'
require 'timeout'

module Helpdesk::Email
  class EmailMigration
    attr_accessor :user_name, :password, :notify_email, :server_name, :start_uid, :end_uid, :start_date, :end_date, :from_address, :to_address, 
                  :subject, :envelope_address, :port, :ssl, :authentication, :folder, :gmail_tags, :tags_name, :uid_list 

    MAX_UID = "99999999"

    def initialize(args={})
      initialise_attributes(args)
      self.port ||= 993
      self.ssl ||= true
      self.folder ||= "INBOX"
      self.gmail_tags ||= false
      retrieve_tags_name
      if mandatory_data_available?
        response = convert_emails_to_tickets
      else
        mailbox_log "Provide all mandatory data in a Hash during initialize.  Mandatory : envelope_address, user_name, password, notify_email, server_name.  Optional : start_uid, end_uid, start_date, port, ssl, authentication"
      end
      response
    end

    def initialise_attributes(attributes = {})
      attributes.each do |name, value|
        if respond_to?("#{name}=")
          send("#{name}=", value)
        end
      end
    end

    def mandatory_data_available?
      (server_name && envelope_address && user_name && password && notify_email)
    end

    def retrieve_tags_name
      if tags_name.present?
        self.tags_name = tags_name.split(",") if tags_name.is_a? String
        self.tags_name = tags_name if tags_name.is_a? Array
      else
        self.tags_name = []
      end
    end

    def get_imap
      Timeout.timeout(15) do
        imap = Net::IMAP.new(server_name, port, ssl)
        unless authentication
          imap.login(user_name, password)
        else
          imap.authenticate(authentication, user_name, password)
        end
        imap.examine(folder)
        mailbox_log "Successfully Logged in customer mailbox"
        return imap
      end
    rescue => e
      mailbox_log "Error occurred While logining customer mailbox #{e.class}, #{e.message}, #{e.backtrace}"
      return nil
    end

    def convert_emails_to_tickets
      start_time = Time.zone.now

      imap = get_imap
      if imap.nil?
        mailbox_log "Imap connection is not available"
        return 0
      end
      failed_uids = []
      @latest_uid = nil

      MaigrationMailer.send_mail(notify_email, "Migration started for folder - #{folder}, email address : #{user_name}")

      begin
        @uids_processed = []
        thread_ids = []
        @tickets_info = []
        uids = imap.uid_search(uid_search_array)

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
              imap = get_imap
            end
            mail = Mail.new(imap.uid_fetch(uid, 'RFC822').first.attr['RFC822'])
            args = {:imap=>imap,:uid=>uid,:tags_name=>tags_name,:gmail_tags=>gmail_tags,:envelope_address=>envelope_address}
            tkt_params = Helpdesk::Email::MigrationMailProcessor.new(args).process_email
            response = Helpdesk::ProcessEmail.new(tkt_params.with_indifferent_access).perform
            mailbox_log "Email is been processed successfully, ticket display id : #{response[:display_id]}, ticket id : #{response[:ticket_id]}, note id : #{response[:note_id]} "
            @uids_processed << uid
            @tickets_info << "#{uid}::#{response[:display_id]}::#{response[:ticket_id]}::#{response[:note_id]},  "
          rescue Exception => e
            Rails.logger.debug "#{e}, #{e.backtrace}"
            mailbox_log "Exceptions occurred during migration #{e}, #{e.backtrace}"
            MaigrationMailer.send_mail(notify_email, "Migration error. UID - #{@latest_uid} Folder - #{folder} ERROR - #{e.class}, #{e.message}, #{e.backtrace}")
            failed_uids.push uid
            unless imap.disconnected?
              imap.logout
              imap.disconnect
            end
            sleep(60)
            imap = get_imap
          end
        end
      rescue Exception => e
        Rails.logger.debug "#{e}, #{e.backtrace}"
        mailbox_log "Exceptions occurred #{e}, #{e.backtrace}"
        MaigrationMailer.send_mail(notify_email, "Migration stopped for folder #{folder}.
                                                   Latest UID #{@latest_uid} failed_uids - #{failed_uids.inspect}
                                                   start_time - #{start_time}".squish!)
        return
      ensure
        imap.logout
      end
      end_time = Time.zone.now
      MaigrationMailer.send_mail(notify_email, "Migration completed for folder #{folder}.
                                                Failed_uids - #{failed_uids.inspect}
                                                Start_time - #{start_time} end_time - #{end_time}
                                                Processed tickets info #{@tickets_info}")
    end

    def uid_search_array
      uid_arr = []
      uid_arr += ["FROM", from_address] if from_address
      uid_arr += ["TO", to_address] if to_address
      uid_arr += ["SINCE", start_date] if start_date
      uid_arr += ["BEFORE", end_date] if end_date
      uid_arr += ["SUBJECT", subject] if subject
      uid_arr += ["UID", "#{start_uid}:#{end_uid}"] if start_uid && end_uid
      uid_arr += ["UID", "1:#{MAX_UID}"] unless uid_arr.present?
      mailbox_log "uid array : #{uid_arr}"
      uid_arr
    end

    def mailbox_log msg
      puts "#{Time.now.utc} - #{Thread.current.object_id} - EmailMigration - #{msg} "
      Rails.logger.info "#{Time.now.utc} - #{Thread.current.object_id} - EmailMigration - #{msg} "
    end
  end

  class MaigrationMailer < ActionMailer::Base
    def send_mail(notify_email,text="")
      headers = {:subject =>       "Mail from console",
                  :to =>            notify_email,
                  :from =>          AppConfig['from_email'],
                  :sent_on =>       Time.now,
                  :content_type =>  "text/html",
                  :body =>           text}
      mail(headers).deliver
    end
  end
end