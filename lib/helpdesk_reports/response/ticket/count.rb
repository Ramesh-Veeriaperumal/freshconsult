class HelpdeskReports::Response::Ticket::Count < HelpdeskReports::Response::Ticket::Base
  
  private
  
  def process_metric
    calculate_general_count_data
    raw_result.each do |row|
      next if row[COLUMN_MAP[:benchmark]] == "f"
      row.each do |col_name, col_value|
        next if AVOIDABLE_COLUMNS.include?(col_name)
        processed_result[col_name] ||= {}
        processed_result[col_name][col_value] ||= 0
        processed_result[col_name][col_value] += row[COLUMN_MAP[:count]].to_i
      end
    end
    processed_result.symbolize_keys!
  end
  
  def calculate_general_count_data
    if benchmark_query?
      previous_count, current_count = 0, 0
      raw_result.each do |row|
        previous_count += row[COLUMN_MAP[:count]].to_i if row[COLUMN_MAP[:benchmark]] == "f"
        current_count  += row[COLUMN_MAP[:count]].to_i if row[COLUMN_MAP[:benchmark]] == "t"
      end
      diff_percentage = calculate_difference_percentage(previous_count, current_count)
      processed_result[:general] = {
        :metric_result    => current_count ,
        :diff_percentage  => diff_percentage
      }
    else
      count = 0
      raw_result.each do |row|
        count += row[COLUMN_MAP[:count]].to_i
      end
      processed_result[:general] = {
        :metric_result => count
      }
    end
  end

end