module HelpdeskReports
  module Export
    class TicketList < Export::Base

      include HelpdeskReports::Export::FieldsHelper
      include HelpdeskReports::Constants::Export
      include HelpdeskReports::Util::Ticket

      attr_reader :s3_bucket_name, :csv_hash, :headers, :options

      def initialize(args)
        super
        @s3_bucket_name = S3_CONFIG[:bi_reports_list_bucket]
        @csv_hash       = args[:export_fields]
        @headers        = report_type==:timespent ? fetch_lifecycle_headers(args) : delete_invisible_fields
        @exceeds_limit  = args[:exceeds_limit]
        @csv_row_limit  = args[:records_limit]
        @options        = args
      end

      def perform
        begin_rescue do
          if options[:report_type].to_sym==:timespent
            lifecycle_ticket_list
          elsif options[:s3_path]
            get_ticket_details
          end
        end
      end

      def get_ticket_details
        csv_headers = headers.collect {|header| csv_hash[header]}
        args = {
          :keys => headers, :headers => csv_headers, :batch_id => 0,
          :complete_export => false, :options => options
        }
        tickets = fetch_ticket_ids
        Reports::ExportsWorker.export(tickets, args)
      end

      def lifecycle_ticket_list
        args = {
              batch_id: 0,
              complete_export: false,
              s3_paths: options[:s3_path],
              s3_bucket_name: @s3_bucket_name,
              options: options,
              headers: @headers
            }
        Reports::ExportsWorker.lifecycle_export(args)
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

      def fetch_lifecycle_headers args={}
        return [] if args.blank?
        case 
        when args[:export_type] == 'aggregate_export'
          l1 = args[:details]['l1']
          l2 = args[:details]['l2']
          l1_name = args[:export_fields][l1]
          l2_name = args[:export_fields][l2]
          csv_headers = [l1_name,l2_name]
          csv_headers << 'None' if args[:res_values].include?(nil)
          res_status = args[:res_values].compact.map(&:to_i).sort
          status_mapping = field_id_to_name_mapping(:status).select{|k,v| res_status.include?(k)}
          csv_headers += res_status.map{|val| (status_mapping[val] || 'Deleted')}
          csv_headers << 'Total'
          csv_headers
        when args[:res_fields].count > 2
          csv_headers = ['Ticket id']
          csv_headers += 'None' if args[:res_values].include?(nil)
          res_val = args[:res_values].compact.map(&:to_i).sort
          name_mapping = field_id_to_name_mapping(args[:export_type]).select{|k,v| res_val.include?(k)}
          csv_headers += res_val.map{|val| (name_mapping[val] || 'Deleted')}
          csv_headers += ['Total Time'] if args[:res_fields].include?('status')
          csv_headers 
        else
          status_mapping = field_id_to_name_mapping(:status).stringify_keys
          status_name = status_mapping[args[:details]['status_value'].to_s] || 'Deleted'
          csv_headers = ['Ticket id', status_name]
        end
      end

    end
  end
end
