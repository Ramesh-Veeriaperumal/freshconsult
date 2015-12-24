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
      end

      def perform
        begin_rescue do
          ticket_data = []
          if s3_path
            fetch_ticket_ids do |objects, index|
              ticket_data << generate_csv_string(objects, index)
            end
          end
          file_path = build_file(ticket_data, TYPES[:csv], TICKET_EXPORT_TYPE ) if ticket_data.present?
          options   = build_options_for_email
          send_email( options, file_path, TICKET_EXPORT_TYPE )
        end
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
