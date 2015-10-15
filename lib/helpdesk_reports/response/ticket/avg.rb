class HelpdeskReports::Response::Ticket::Avg < HelpdeskReports::Response::Ticket::Base

  include HelpdeskReports::Util::Ticket
  
  private

  def process_metric
    @helper_hash = {}

    calculate_general_avg_data
    raw_result.each do |row|
      next if row[COLUMN_MAP[:benchmark]] == "f"
      row.each do |column,value|
        next if (AVOIDABLE_COLUMNS.include? column)
          
        value = label_for_x_axis(row["y"].to_i, value.to_i, column, date_range, row["mon"].to_i) if trend_column? column
        
        processed_result[column] ||= {}
        @helper_hash[column] ||= {}

        processed_result[column][value] ||= 0
        @helper_hash[column][value] ||= {:avg => 0, :count => 0}

        processed_result[column][value]    = aggregate_avg(@helper_hash[column][value], row)
        @helper_hash[column][value][:avg]   = processed_result[column][value]
        @helper_hash[column][value][:count] += row[COLUMN_MAP[:count]].to_i
      end
    end
    pad_result_with_complete_time_range
    processed_result.symbolize_keys!
  end

  def calculate_general_avg_data
    if benchmark_query?
      previous_avg, current_avg = {:avg => 0.0, :count => 0}, {:avg => 0.0, :count => 0}
      raw_result.each do |row|
        case row[COLUMN_MAP[:benchmark]]
          when "f"
            previous_avg[:avg]    = aggregate_avg(previous_avg, row)
            previous_avg[:count] += row[COLUMN_MAP[:count]].to_i
          when "t"
            current_avg[:avg]    = aggregate_avg(current_avg, row)
            current_avg[:count] += row[COLUMN_MAP[:count]].to_i
        end
      end
      diff_percentage = calculate_difference_percentage(previous_avg[:avg], current_avg[:avg])
      processed_result[:general] = {
        :metric_result    => current_avg[:avg],
        :diff_percentage  => diff_percentage
      }
    else
      final_avg = {:avg => 0.0, :count => 0}
      raw_result.each do |row|
        final_avg[:avg]   = aggregate_avg(final_avg, row)
        final_avg[:count]+= row[COLUMN_MAP[:count]].to_i
      end      
      processed_result[:general] = {
        :metric_result => final_avg[:avg]
      }
    end
  end
  
  # calculates aggregate average using below formula
  # avg_1, count_1 and avg_2, count_2
  # resulting_avg = (avg_1*count_1 + avg_2*count_2) / count_1 + count_2
  def aggregate_avg avg_hash, new_row
    cur_avg = avg_hash[:avg] * avg_hash[:count]
    new_row_avg = new_row[COLUMN_MAP[:avg]].to_f * new_row[COLUMN_MAP[:count]].to_i
    total_count = avg_hash[:count] + new_row[COLUMN_MAP[:count]].to_i
    resulting_avg = (cur_avg + new_row_avg) / total_count.to_f if total_count != 0
    resulting_avg ? resulting_avg.to_i : 0
  end

  def pad_result_with_complete_time_range
    ["doy", "w","mon","qtr", "y"].each do |trend|
      original_hash, padding_hash     = processed_result[trend], range(trend)
      processed_result[trend] = padding_hash.merge(original_hash){|k, old_val, new_val| old_val + new_val} if original_hash.present?
    end
  end

end
