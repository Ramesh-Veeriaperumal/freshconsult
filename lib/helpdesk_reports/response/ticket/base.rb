class HelpdeskReports::Response::Ticket::Base

  include HelpdeskReports::Constants
  include HelpdeskReports::Util::Ticket

  attr_accessor :raw_result, :processed_result, :date_range, :report_type, :start_date, :end_date

  def initialize result, date_range, report_type, query_type, pdf_export
    @raw_result       = result
    @date_range       = date_range
    @report_type      = report_type.upcase.to_sym
    @query_type       = query_type
    @pdf_export       = pdf_export
    dates             = date_range.split("-")
    @start_date       = Date.parse(dates.first)
    @end_date         = dates.length > 1 ?  Date.parse(dates.second) : start_date   
    @processed_result = {}
  end

  def process
    process_metric if raw_result.present? # return empty hash if ZERO sql rows
    sort_group_by_values if @pdf_export
    map_field_ids_to_values
    processed_result
  end

  #Already preprocessed in the reports service!
  def process_metric
    @processed_result = @raw_result
  end

  private

  def map_flexifield_to_label
    processed_result.keys.each do |column_name|
      next unless column_name.to_s.starts_with?("ffs")
      label = flexifield_label_from_db(column_name)
      processed_result[label] = processed_result[column_name]
      processed_result.delete(column_name)
    end
  end

  def flexifield_label_from_db column_name
    def_entry = Account.current.flexifield_def_entries.where(:flexifield_name => column_name).first
    def_entry ? def_entry.ticket_field.label.to_sym : ""
  end

  def map_field_ids_to_values
    processed_result.each do |column_name, value|
      if reverse_mapping_required?(column_name)
        mapping_hash = field_id_to_name_mapping(column_name)
        convert_id_to_names(column_name, value, mapping_hash)
        #merge_empty_fields_with_zero(value,mapping_hash)
      end
    end
  end

  # If we have result for an option (say custom ticket_type, status) which is been deleted now
  # it is shown as NA in report result (to match with metric result)
  # All such values are added in single NA for Count metrics.
  # For Avg and Percentage metrics, these cannot be simply added (illegal maths), hence
  # these values are shown as NA-1, NA-2 .. likewise, if there exists multiple such entries.
  def convert_id_to_names(column_name, value, mapping_hash)
    avg_count, percentage_count = 0 , 0
    value.keys.each do |k| 
      next if k == PDF_GROUP_BY_LIMITING_KEY
      new_key = mapping_hash[k.to_i] || NOT_APPICABLE 
      value[new_key] ||= {value: 0, id: nil}
      
      if self.class == HelpdeskReports::Response::Ticket::Count     
        val = value[new_key][:value].to_i + value[k] #incase we have multiple NA values
      elsif self.class == HelpdeskReports::Response::Ticket::Avg
        val = new_key == NOT_APPICABLE ? aggregate_avg(@helper_hash[column_name.to_s][k],{"avg"=>value[new_key][:value].to_i, "count"=>avg_count}) : value[k]
        avg_count += @helper_hash[column_name.to_s][k][:count] if new_key == NOT_APPICABLE
      elsif self.class == HelpdeskReports::Response::Ticket::Percentage
        percentage_count += 1 if new_key == NOT_APPICABLE and percentage_count < 2
        val = new_key == NOT_APPICABLE ? (value[new_key][:value].to_i + sla_percentage(column_name, k))/percentage_count : value[k]
      end
      
      value[new_key] = {value: val, id: new_key == NOT_APPICABLE ? nil : k}
      value.delete(k)
    end
  end

  def sort_group_by_values
    return unless report_type == :GLANCE && @query_type != :bucket 
    processed_result.each do |gp_by, values|
      values = values.to_a
      next if gp_by == :general 
      values = values.sort_by{|i| i.second}.reverse!
      processed_result[gp_by] = values.to_h
      club_keys_for_export_pdf(gp_by, processed_result[gp_by]) if(processed_result[gp_by].size > PDF_GROUP_BY_LIMIT)
    end
  end
  
  def club_keys_for_export_pdf(column_name, value)
    avg_count, percentage_count = 0 , 0
    arr = value.keys
    arr.slice(PDF_GROUP_BY_LIMIT-1,arr.length).each do |k| 
      new_key = PDF_GROUP_BY_LIMITING_KEY
      value[new_key] ||= {value: 0, id: nil}
      if self.class == HelpdeskReports::Response::Ticket::Count     
        val = value[new_key][:value].to_i + value[k] #incase we have multiple NA values
      elsif self.class == HelpdeskReports::Response::Ticket::Avg
        val = aggregate_avg(@helper_hash[column_name.to_s][k],{"avg"=>value[new_key][:value].to_i, "count"=>avg_count})
        avg_count += @helper_hash[column_name.to_s][k][:count]
      elsif self.class == HelpdeskReports::Response::Ticket::Percentage
        percentage_count += 1 if percentage_count < 2
        val = (value[new_key][:value].to_i + sla_percentage(column_name, k))/percentage_count
      end
      value[new_key] = {value: val, id: nil}
      value.delete(k)
    end
  end
  
  def merge_empty_fields_with_zero(value,mapping_hash)
    mapping_hash.keys.each do |k|
      value[mapping_hash[k]] ||= 0
    end
  end

  def calculate_difference_percentage previous_val, current_val
    return NOT_APPICABLE if previous_val == 0 || [previous_val, current_val].include?(NOT_APPICABLE)
    precentage = (current_val - previous_val)*100/ previous_val.to_f
    precentage.round
  end
    
  def benchmark_query?
    !raw_result.blank? and !raw_result.first.blank? and !raw_result.first[COLUMN_MAP[:benchmark]].blank?
  end

  def range trend
    padding_hash = {}

    if trend == "y" 
      (start_date.year..end_date.year).each do |i| 
          i = label_for_x_axis(i, i, trend)
          padding_hash[i] = 0 
      end
    elsif trend == 'w'
      (start_date.beginning_of_week..end_date.beginning_of_week).each do |i| 
          i = label_for_x_axis(nil, i, trend)
          padding_hash[i] = 0 
      end
    elsif trend == 'doy'
      (start_date..end_date).each do |i| 
          i = label_for_x_axis(nil, i, trend)
          padding_hash[i] = 0 
      end
    else
      (start_date.year..end_date.year).each do |y|
        start_point  = (start_date.year == y) ? date_part(start_date, trend) : 1
        end_point = (end_date.year == y) ? date_part(end_date, trend) : TREND_MAX_VALUE[trend] 
        
        (start_point..end_point).each do |i|
          i = label_for_x_axis(y, i, trend)
          padding_hash[i] = 0
        end
      end
    end
    padding_hash
  end

  def label_for_x_axis year, point, trend
    timestamp_needed = (report_type == :PERFORMANCE_DISTRIBUTION) #Performance Reports need timestamp values for line chart
    case trend
      when "doy"
        date = point.is_a?(Date) ? point : Date.parse(point)
        timestamp_needed ? convert_date_to_timestamp(date) : "#{date.strftime('%d %b, %Y')}"  
      when "w"
        week     = point.is_a?(Date) ? point : Date.parse(point)
        res_date = [week.beginning_of_week,week.end_of_week]
        if timestamp_needed
          convert_date_to_timestamp(res_date[0])
        else
          start_week = res_date[0] < start_date ? start_date.strftime('%d %b, %Y') : res_date[0].strftime('%d %b, %Y')
          end_week = res_date[1] > end_date ? end_date.strftime('%d %b, %Y') : res_date[1].strftime('%d %b, %Y')
          start_week + " - " + end_week
        end
      when "mon"
        date = "#{Date::ABBR_MONTHNAMES[point.to_i]}, #{year}"
        timestamp_needed ? convert_date_to_timestamp(date) : "#{date}"
      when "qtr"
        qtr = (point.to_i - 1 ) * 3
        start_month = Date::ABBR_MONTHNAMES[qtr + 1]
        end_month   = Date::ABBR_MONTHNAMES[qtr + 3]
        timestamp_needed ? convert_date_to_timestamp("#{start_month}, #{year}") : "#{start_month} - #{end_month}, #{year}"
      when "y"
        timestamp_needed ? convert_date_to_timestamp(Date.ordinal(year)) : "#{year}"
      end
    end

    def convert_date_to_timestamp date
      date = date.is_a?(Date) ? date : Date.parse(date)
      date.strftime('%s').to_i * 1000
    end
end
