class HelpdeskReports::Export::Timespent < HelpdeskReports::Export::Report
  
  include HelpdeskReports::Util::Ticket
  include HelpdeskReports::Constants::Ticket
  include HelpdeskReports::Helper::FilterFields
  include ExportCsvUtil

  attr_accessor :args, :options

  def initialize args={}
    @args = args.symbolize_keys
    @options = args[:options].symbolize_keys
  end

  def generate_csv_string
    args[:headers] ||= {}
    formatted_result =  if (options[:export_type] == 'aggregate_export')
                          format_aggregate_results
                        elsif options[:res_fields].size > 2
                          format_ticket_list_results
                        else
                          process_final_ticket_list
                        end

    csv_string = CSVBridge.generate do |csv|
      csv << @args[:headers]
      formatted_result.each do |res_hash|
        csv << @result_headers.collect{|field| res_hash[field] }
      end
    end
    csv_string
  end

  def format_aggregate_results
    formatted_result = []
    l1_header = options[:details]['l1']
    l2_header = options[:details]['l2']
    rows = CSV.parse(AwsWrapper::S3.read(args[:s3_bucket_name], args[:s3_key]),{ :col_sep => '|' })
    return [] if rows.blank?
    rows.shift
    res_status = options[:res_values].map(&:to_i).sort.map(&:to_s)
    @result_headers = [l1_header,l2_header] + res_status + ["total_time"]
    l1_name_mapping = field_id_to_name_mapping(options[:details]['l1']).stringify_keys
    l2_name_mapping = field_id_to_name_mapping(options[:details]['l2']).stringify_keys
    status_name = field_id_to_name_mapping('status').stringify_keys
    grouped_rows_hash = rows.group_by{|row| [row[0],row[1]] }
    grouped_rows_hash.each do |grp_arr, arr_of_arr|
      res_hash = {}
      l1_val, l2_val = grp_arr
      res_hash[l1_header] = (l1_val == "\\N") ? 'None' : (l1_name_mapping[l1_val] || 'Deleted')
      res_hash[l2_header] = (l2_val == "\\N") ? 'None' : (l2_name_mapping[l2_val] || 'Deleted')
      res_hash['total_time'] = 0
      arr_of_arr.each do |row|
        time = row[3].to_i
        res_hash[row[2]] = convert_time_format time
        res_hash['total_time'] += time
      end
      res_hash['total_time'] = convert_time_format(res_hash['total_time'])
      formatted_result << res_hash
    end
    formatted_result
  end

  def format_ticket_list_results
    formatted_result,res_val = [], []
    rows = CSV.parse(AwsWrapper::S3.read(args[:s3_bucket_name], args[:s3_key]),{ :col_sep => '|' })
    return [] if rows.blank?
    rows.shift
    res_val << "\\N" if options[:res_values].include?(nil)
    res_val += options[:res_values].compact.map(&:to_i).sort.map(&:to_s)
    @result_headers = ['display_id'] + res_val
    @result_headers << 'total_time' if options[:res_fields].include?('status')
    rec_grp_hash = rows.group_by{|arr| arr[0]}
    rec_grp_hash.each do |grp,arr_of_arr|
      rec_hash = {}
      rec_hash['display_id'] = grp
      rec_hash['total_time'] = 0
      arr_of_arr.each do |row| 
        time = row[2].to_i
        rec_hash[row[1]] = convert_time_format time
        rec_hash['total_time'] += row[2].to_i
      end
      rec_hash['total_time'] = convert_time_format(rec_hash['total_time']) if rec_hash['total_time']
      formatted_result << rec_hash
    end
    formatted_result
  end

  def process_final_ticket_list
    formatted_result = []
    @result_headers = ['display_id', 'status']
    rows = CSV.parse(AwsWrapper::S3.read(args[:s3_bucket_name], args[:s3_key]),{ :col_sep => '|' })
    return [] if rows.blank?
    rows.shift
    rows.each{|row| formatted_result << {'display_id' => row[0], 'status' => convert_time_format(row[1])}}
    formatted_result
  end

  def convert_time_format time
    time = time.to_i
    hrs = time / 3600
    mins = ((time / 60) % 60)
    secs = time % 60
    time > 3600 ? "#{hrs}h #{mins}m" : "#{mins}m #{secs}s"
  end

end