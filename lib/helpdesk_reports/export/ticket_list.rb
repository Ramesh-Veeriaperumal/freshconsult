module HelpdeskReports
  module Export
    class TicketList < Export::Base

      include HelpdeskReports::Export::FieldsHelper
      include HelpdeskReports::Constants::Export

      attr_reader :s3_bucket_name, :s3_path, :csv_hash, :headers

      def initialize(args)
        super
        @s3_bucket_name = S3_CONFIG[:bi_reports_list_bucket]
        @s3_path        = args[:s3_path]
        @csv_hash       = args[:export_fields]
        @headers        = delete_invisible_fields
        @exceeds_limit  = args[:exceeds_limit]
        @csv_row_limit  = args[:records_limit]
      end

      def perform
        begin_rescue do
          if s3_path
            csv_headers = headers.collect {|header| csv_hash[header]}
            ticket_data = CSVBridge.generate do |csv|
              csv << csv_headers
              fetch_tickets_data(csv)
              csv << t('helpdesk_reports.export_exceeds_row_limit_msg', :row_max_limit => @csv_row_limit) if @exceeds_limit
            end
            file_path = build_file(ticket_data, TYPES[:csv], TICKET_EXPORT_TYPE ) if ticket_data.present?
            options   = build_options_for_email
            send_email( options, file_path, TICKET_EXPORT_TYPE )
          end
        end
      end

      private

      def fetch_tickets_data(tickets = [])
        s3_objects.each_with_index do |object, index|
          ticket_ids          = ticket_ids_from_s3(object.key)
          next if ticket_ids.blank?
          generate_ticket_data(tickets, non_archive_tickets(ticket_ids[:non_archive]),false) unless ticket_ids[:non_archive].empty?
          generate_ticket_data(tickets, archive_tickets(ticket_ids[:archive]),true) unless ticket_ids[:archive].empty?
        end
      end
      
      def s3_objects
        objs ||= AwsWrapper::S3.list(s3_bucket_name, s3_path, true)
      end

      def ticket_ids_from_s3(s3_key)
        non_archive_ticket_ids, archive_ticket_ids, rows = [], [], []
        rows = CSV.parse(AwsWrapper::S3.read(s3_bucket_name, s3_key),{ :col_sep => '|' })
        return {} if rows.blank?
        rows.shift # To remove the headers
        rows.each do |row|
          non_archive_ticket_ids << row[0].strip if row[1].strip == "f"
          archive_ticket_ids     << row[0].strip if row[1].strip == "t"
        end
        { :non_archive => non_archive_ticket_ids, :archive => archive_ticket_ids }
      end

      def build_options_for_email
        {
          :filters         => params[:select_hash],
          :ticket_export   => true,
          :selected_metric => construct_selected_metric(params[:metric_title],params[:metric_value])
        }
      end

      def construct_selected_metric( metric, values )
        value  = values.to_s.split(" : ")
        value.length == 2 ? " #{metric} ( #{value[0]} ) " : " #{metric} "
      end

    end
  end
end
