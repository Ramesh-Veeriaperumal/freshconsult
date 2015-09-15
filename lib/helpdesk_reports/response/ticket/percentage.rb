class HelpdeskReports::Response::Ticket::Percentage < HelpdeskReports::Response::Ticket::Base
  
  private 
  
  def process_metric
    helper_hash = {}
    calculate_general_percentage_data
    
    return if processed_result[:general][:metric_result] == NOT_APPICABLE
    
    raw_result.each do |row|
      next if  row[COLUMN_MAP[:benchmark]] == "f"
      violated = sla_column(row)
      row.each do |col_name, col_value|
        next if AVOIDABLE_COLUMNS.include?(col_name)

        helper_hash[col_name] ||= {}
        helper_hash[col_name][col_value] ||= {:violated => 0, :not_violated => 0}
        case violated
        when "t"
          helper_hash[col_name][col_value][:violated] += row[COLUMN_MAP[:count]].to_i 
        when "f"
          helper_hash[col_name][col_value][:not_violated] += row[COLUMN_MAP[:count]].to_i
        end
      end
    end
    
    helper_hash.each do |col_name, col_value|
      col_value.each do |val, res|
        processed_result[col_name] ||= {}
        processed_result[col_name][val] = calculate_sla_percentage(res[:not_violated], res[:violated])
      end
    end
  end
  
  def calculate_general_percentage_data
    if benchmark_query?
      previous_data, current_data = {:violated => 0, :not_violated => 0}, {:violated => 0, :not_violated => 0}
      raw_result.each do |row|
        violated = sla_column(row)

        case row[COLUMN_MAP[:benchmark]]
        when "t"
          case violated
          when "t"
            current_data[:violated] += row[COLUMN_MAP[:count]].to_i 
          when "f"
            current_data[:not_violated] += row[COLUMN_MAP[:count]].to_i
          end
        when "f"
          case violated
          when "t"
            previous_data[:violated] += row[COLUMN_MAP[:count]].to_i 
          when "f"
            previous_data[:not_violated] += row[COLUMN_MAP[:count]].to_i
          end
        end
      end

      sla_percentage_current  = calculate_sla_percentage(current_data[:not_violated], current_data[:violated])
      sla_percentage_previous = calculate_sla_percentage(previous_data[:not_violated], previous_data[:violated])
      diff_percentage = calculate_difference_percentage(sla_percentage_previous, sla_percentage_current)
      processed_result[:general] = {
        :metric_result    =>  "#{sla_percentage_current}%",
        :diff_percentage  =>  diff_percentage
      }
    else
      final_data = {:violated => 0, :not_violated => 0}
      raw_result.each do |row|
        violated = sla_column(row)
        case violated
        when "t"
          final_data[:violated] += row[COLUMN_MAP[:count]].to_i
        when "f"
          final_data[:not_violated] += row[COLUMN_MAP[:count]].to_i      
        end 
      end
      sla_percentage_final = calculate_sla_percentage final_data[:not_violated], final_data[:violated]
      processed_result[:general] = {
        :metric_result => "#{sla_percentage_final}%"
      }
    end
  end

  def calculate_sla_percentage inside_sla, outside_sla
    total = inside_sla + outside_sla
    return NOT_APPICABLE if total == 0
    percentage = (inside_sla*100) / total.to_f if total != 0
    percentage.round
  end

  def sla_column row
    row[COLUMN_MAP[:fr_escalated]] or row[COLUMN_MAP[:is_escalated]] or row[COLUMN_MAP[:fcr_violation]]
  end

end