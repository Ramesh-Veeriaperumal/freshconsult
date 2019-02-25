#args = {:user_name=>"user@gmail.com", :password=>"password", :notify_email=>"notify@gmail.com", :envelope_address=>"envelope@local.freshdesk.com", :server_name=>"imap.gmail.com", :folder=>"INBOX", :tags_name=>["email_import"], :gmail_tags=>false, :start_time=>"DD-MMM-YYYY HH:MM:SS +0000", :end_time=>"DD-MMM-YYYY HH:MM:SS +0000"}
#Helpdesk::Email::EmailMigration.new(args).uids_list
#Helpdesk::Email::EmailMigration.new(args).process

module Helpdesk::Email
  class Migration
    
    attr_accessor :args

    def initialize(args={})
      self.args = args
      retrieve_tags_name
      self.args[:skip_notification] ||= true
      self.args[:enable_outgoing] ||= true
    end

    def retrieve_tags_name
      if args[:tags_name].present?
        self.args[:tags_name] = args[:tags_name].split(",") if args[:tags_name].is_a? String
        self.args[:tags_name] = args[:tags_name] if args[:tags_name].is_a? Array
      else
        self.args[:tags_name] = []
      end
    end

    def process
      if args[:file_path]
        Helpdesk::Email::Migrate::EmlMigration.new(args).process 
      else
        Helpdesk::Email::Migrate::ImapMigration.new(args).process 
      end
    end

    def uids_list
      Helpdesk::Email::Migrate::ImapMigration.new(args).uids_list
    end
  end
end