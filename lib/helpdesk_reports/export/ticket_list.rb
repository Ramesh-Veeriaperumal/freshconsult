module HelpdeskReports
  module Export
    class TicketList < Export::Base

      include HelpdeskReports::Export::FieldsHelper
      include HelpdeskReports::Export::Constants
      include HelpdeskReports::Export::Query

      attr_reader :csv_hash, :params, :s3_path, :s3_bucket_name, :report_type,
                  :export_id, :portal_url, :headers, :select_hash, :selected_metric

      def initialize(args)
        super
        @csv_hash        = args[:export_fields]
        @portal_url      = args[:portal_url]
        @s3_path         = args[:s3_path]
        @export_id       = args[:export_id]
        @report_type     = args[:report_type]
        @params          = args[:query_hash]
        @select_hash     = args[:select_hash]
        @headers         = delete_invisible_fields
        @s3_bucket_name  = S3_CONFIG[:bi_reports_list_bucket]
        @selected_metric = construct_selected_metric(args[:metric_title],args[:metric_value])
      end

      def trigger
        ticket_data = []
        is_empty_data = true
        file_path = ""
        
        if s3_path
          fetch_ticket_ids do |objects, index|
            ticket_data << generate_csv_string(objects, index)
          end
        end

        if ticket_data.present?
          is_empty_data =  false
          file_path = build_file(ticket_data, "csv")
        end

        send_email(is_empty_data, file_path)
      end

      private

        def fetch_ticket_ids(&block)
          s3_objects.each_with_index do |object, index|
            ticket_ids          = ticket_ids_from_s3(object.key)
            next if ticket_ids.blank?
            non_archive_tickets = ticket_ids[:non_archive].empty? ? [] : generate_ticket_data(non_archive_tickets(ticket_ids[:non_archive]),false)
            archive_tickets     = ticket_ids[:archive].empty? ?     [] : generate_ticket_data(archive_tickets(ticket_ids[:archive]),true)
            yield(non_archive_tickets + archive_tickets, index) if block_given?
          end
        end

        def construct_selected_metric(metric,values)
          value  = values.to_s.split(" : ")
          value.length == 2 ? " #{metric} ( #{value[0]} ) " : " #{metric} "
        end

        def send_email is_empty_data, file_path
          options = {
            :user => User.current,
            :domain => portal_url,
            :report_type => report_type,
            :date_range => params["date_range"],
            :ticket_export => true,
            :filters => select_hash,
            :selected_metric => selected_metric
          }

          begin
            if !is_empty_data
              if @attachment_via_s3
                file_name = file_path.split("/").last
                options.merge!(:export_url => user_download_url(file_name,"report_export")) # upload file on S3 and send download link
              else
                options.merge!(file_path: file_path) # Attach file in mail itself
              end    
                ReportExportMailer.bi_report_export(options)
            else
              ReportExportMailer.no_report_data(options)
            end
          rescue Exception => err
            NewRelic::Agent.notice_error(err)
          ensure
            Account.current.data_exports.find(export_id).update_attributes(:status => DataExport::EXPORT_STATUS[:completed])
            FileUtils.rm_f(file_path) if File.exist?(file_path)
          end
        end

        def s3_objects
          begin_rescue { objs ||= AwsWrapper::S3.list(s3_bucket_name, s3_path, true) }
        end

        def ticket_ids_from_s3(s3_key)
          non_archive_ticket_ids, archive_ticket_ids, rows = [], [], []
          begin_rescue do
            rows = CSV.parse(AwsWrapper::S3.read(s3_bucket_name, s3_key),{ :col_sep => '|' })
            return {} if rows.blank?
            rows.shift # To remove the headers
            rows.each do |row|
              non_archive_ticket_ids << row[0].strip if row[1].strip == "f"
              archive_ticket_ids     << row[0].strip if row[1].strip == "t"
            end
          end
          { :non_archive => non_archive_ticket_ids, :archive => archive_ticket_ids }
        end

        def begin_rescue(&block)
          begin
            yield if block_given?
          rescue Exception => e
            NewRelic::Agent.notice_error(e)
            subj_txt = "Reports Export exception for #{Account.current.id}"
            message  = "#{e.inspect}\n #{e.backtrace.join("\n")}"
            DevNotification.publish(SNS["reports_notification_topic"], subj_txt, message)
          end
        end

    end
  end
end
