module HelpdeskReports
  module Export
    class Base
      
      include HelpdeskReports::Export::FieldsHelper
      include HelpdeskReports::Export::Constants
      include HelpdeskReports::Export::Query
      include ::Export::Util
      
      attr_reader :s3_path, :s3_bucket_name, :portal_url, :date_range
      
      def initialize(args)
        args.symbolize_keys!
        user = Account.current.users.find(args[:user_id])
        user.make_current
        
        @portal_url      = args[:portal_url]
        @s3_path         = args[:s3_path]
        @date_range      = args[:date_range]
        @s3_bucket_name  = S3_CONFIG[:bi_reports_list_bucket]
        check_and_create_export(DATA_EXPORT_TYPE)
      end
            
      def build_export_file(&block)
        s3_objects.each_with_index do |object, index|
          ticket_ids          = ticket_ids_from_s3(object.key)
          next if ticket_ids.blank?
          non_archive_tickets = ticket_ids[:non_archive].empty? ? [] : execute_non_archive_query(ticket_ids[:non_archive])
          archive_tickets     = ticket_ids[:archive].empty? ?     [] : execute_archive_query(ticket_ids[:archive])
          yield(non_archive_tickets + archive_tickets, index) if block_given?    
        end
      end
      
      def send_email
        DataExportMailer.deliver_reports_export({
          :user   => User.current, 
          :domain => portal_url,
          :export_url => hash_url(Account.current.host),
          :date_range  => date_range
        })
      end
      
      private
      
        def s3_objects
          begin_rescue { objs ||= AwsWrapper::S3.list(s3_bucket_name, s3_path, true) }
        end
        
        def ticket_ids_from_s3(s3_key)
          non_archive_ticket_ids, archive_ticket_ids, rows = [], [], []
          begin_rescue do
            rows = CSV.parse(AwsWrapper::S3.read(s3_bucket_name, s3_key))
            return {} if rows.blank?
            rows.shift # To remove the headers
            rows.each do |row|
              non_archive_ticket_ids << row[1].strip if row[2].strip == "false"
              archive_ticket_ids     << row[1].strip if row[2].strip == "true"
            end
          end
          { :non_archive => non_archive_ticket_ids, :archive => archive_ticket_ids }
        end
        
        def begin_rescue(&block)
          begin
            yield if block_given?
          rescue Exception => e
            NewRelic::Agent.notice_error(e)
            puts e.inspect
            puts e.backtrace.join("\n")
            subj_txt = "Reports Export exception for #{Account.current.id}"
            message  = "#{e.inspect}\n #{e.backtrace.join("\n")}"
            DevNotification.publish(SNS["reports_notification_topic"], subj_txt, message)
          end
        end
    end
  end
end