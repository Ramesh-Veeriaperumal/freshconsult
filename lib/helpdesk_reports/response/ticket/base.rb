class HelpdeskReports::Response::Ticket::Base

  include HelpdeskReports::Constants
  include HelpdeskReports::Util::Ticket

  attr_accessor :raw_result, :processed_result, :date_range, :report_type

  def initialize result, date_range, report_type, query_type, pdf_export
    @raw_result       = result
    @date_range       = date_range
    @report_type      = report_type.upcase.to_sym
    @processed_result = {}
    @query_type       = query_type
    @pdf_export       = pdf_export
  end

  def process
    process_metric if raw_result.present? # return empty hash if ZERO sql rows
    sort_group_by_values
    map_field_ids_to_values
    #map_flexifield_to_label # TODO: remove this action. Not required anymore.
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
    return unless sorting_required?
    processed_result.each do |gp_by, values|
      values = values.to_a
      next if gp_by == :general 
      not_numeric = values.collect{|i| i unless i.second.is_a? Numeric}.compact
      values = (values - not_numeric).sort_by{|i| i.second}.reverse!
      processed_result[gp_by] = (values|not_numeric).to_h
      club_keys_for_export_pdf(gp_by, processed_result[gp_by]) if (@pdf_export && @query_type!=:bucket)
    end
  end
  
  def sorting_required?
    report_type == :GLANCE && @query_type != :bucket
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
  
  def explain 
    puts JSON.pretty_generate @processed_result
  end
  
  def trend_column? column
    ["doy","w","mon","qtr","y"].include? column
  end
  
  def range trend
    dates = date_range.split("-")
    start_day = Date.parse(dates.first)
    end_day = dates.length > 1 ?  Date.parse(dates.second) : start_day
    padding_hash = {}

    if trend == "y" 
      (start_day.year..end_day.year).each do |i| 
          i = label_for_x_axis(i, i, trend, date_range)
          padding_hash[i] = 0 
      end
    else
      end_year = end_day.year
      if trend == 'w' && end_day.month == 1 && end_day.cweek >= 52
        end_year = end_day.year - 1
      end

      (start_day.year..end_year).each do |y|
        start_point  = (start_day.year == y) ? date_part(start_day, trend) : 1
        end_point = (end_year == y) ? date_part(end_day, trend) : trend_max_value(trend, y)
        
        (start_point..end_point).each do |i|
          month = trend == "w" ? week_1_specialcase(y) : nil
          i = label_for_x_axis(y, i, trend, date_range, month)
          padding_hash[i] = 0
        end
      end
    end
    padding_hash
  end
  
  def week_1_specialcase year
    # By definition (ISO 8601), the first week of a year contains January 4 of that year. (The ISO-8601 week starts on Monday.) 
    # Due to above definiton it can happen that an year has two separate weeks with week number 1, which is an expected behaviour
    # and in any such case, week number 1 occurring in December is actually week number 1 of next year.
    # Below code is written to get month as we need month to distinguis between week 1 occuring in Jan or Dec.
    start_day = Date.parse(date_range.split("-").first)
    if start_day.year == year and start_day.cweek == 1
      return start_day.month
    else
      nil
    end
  end

  def trend_max_value trend, year
    case trend
      when "doy"
        Date.leap?(year) ? TREND_MAX_VALUE["leap_year"] : TREND_MAX_VALUE["year"]
      else
        if trend == "w"
          start_day = Date.parse(date_range.split("-").first)
          return 1 if start_day.year == year and start_day.cweek == 1 and start_day.month == 12
        end
        TREND_MAX_VALUE[trend]
    end
  end

  def label_for_x_axis year, point, trend, date_range, month = nil
    case trend
      when "doy"
        date = "#{Date.ordinal(year, point).strftime('%d %b')}, #{year}"
      when "w"
        date = "#{week_to_date(point, year, date_range, month)}"      
      when "mon"
        date = "#{Date::ABBR_MONTHNAMES[point]}, #{year}"      
      when "qtr"
        date = "#{Date::ABBR_MONTHNAMES[((point-1)*3 )+ 1]} - #{Date::ABBR_MONTHNAMES[((point-1)*3 )+ 3]}, #{year}"      
      when "y"
        date = "#{point}"
    end
    date_according_to_report_type date, trend, year
  end
  
  def date_according_to_report_type date, trend, year
    r_t_code = REPORT_TYPE_BY_KEY[report_type]
    case trend
      when "qtr"
        r_t_code == 104 ? (Date.parse(date.split("-").first+year.to_s).strftime('%s').to_i * 1000) : date
      when "y"
        r_t_code == 104 ? (Date.ordinal(date.to_i).strftime('%s').to_i * 1000) : date
      else
        r_t_code == 104 ? (Date.parse(date).strftime('%s').to_i * 1000) : date
      end
  end

  def week_to_date week, year, date_range, month
    dates      = date_range.split("-")
    start_date = Date.parse(dates.first)
    end_date   = dates.last ? Date.parse(dates.last) : Date.parse(dates.first)
    res_date   = date_from_week week, month, year #Date.commercial(year, week)
    if REPORT_TYPE_BY_KEY[report_type] == 104
      res_date[0]
    else
      start_week = res_date[0] < start_date ? start_date.strftime('%d %b, %Y') : res_date[0].strftime('%d %b, %Y')
      end_week = res_date[1] > end_date ? end_date.strftime('%d %b, %Y') : res_date[1].strftime('%d %b, %Y')
      start_week + " - " + end_week
    end
    
  end
  
  def date_from_week week, month, year
    year += 1 if month && week == 1 && month == 12
    year -= 1 if month && week >= 52 && month == 1
    [Date.commercial(year, week),Date.commercial(year, week, 7)]
  end

end
