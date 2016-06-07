module HelpdeskReports
  module Export
    class TicketList < Export::Base

      include HelpdeskReports::Export::FieldsHelper
      include HelpdeskReports::Constants::Export

      attr_reader :s3_bucket_name, :csv_hash, :headers, :options

      def initialize(args)
        super
        @s3_bucket_name = S3_CONFIG[:bi_reports_list_bucket]
        @csv_hash       = args[:export_fields]
        @headers        = delete_invisible_fields
        @exceeds_limit  = args[:exceeds_limit]
        @csv_row_limit  = args[:records_limit]
        @options        = args
      end

      def perform
        begin_rescue do
          if options[:s3_path]
            csv_headers = headers.collect {|header| csv_hash[header]}
            args = {
              :keys => headers, :headers => csv_headers, :batch_id => 0,
              :complete_export => false, :options => options
            }
            tickets = fetch_ticket_ids
            Reports::ExportsWorker.export(tickets, args)
          end
        end
      end

      private

      def fetch_ticket_ids
        ticket_ids = {:non_archive => [], :archive => []}
        s3_objects.each do |object|
          s3_ids = ticket_ids_from_s3(object.key)
          ticket_ids.merge!(s3_ids) { |i| ticket_ids[i] + s3_ids[i] }
        end
        ticket_ids
      end
      
      def s3_objects
        @objs ||= AwsWrapper::S3.list(s3_bucket_name, options[:s3_path], true)
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

      def construct_selected_metric( metric, values )
        value  = values.to_s.split(" : ")
        value.length == 2 ? " #{metric} ( #{value[0]} ) " : " #{metric} "
      end

    end
  end
end
