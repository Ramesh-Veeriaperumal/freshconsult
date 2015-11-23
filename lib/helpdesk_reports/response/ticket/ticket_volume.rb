class HelpdeskReports::Response::Ticket::TicketVolume < HelpdeskReports::Response::Ticket::Base

  private

  def process_metric
    processed_result["RECEIVED_TICKETS"], processed_result["RESOLVED_TICKETS"] = {}, {}
    general_and_week_trend_data("RECEIVED_TICKETS", "RESOLVED_TICKETS")
    raw_result.each do |row|
      next if row[COLUMN_MAP[:benchmark]] == "f"

      row.each do |col_name,col_value|
        next if (AVOIDABLE_COLUMNS.include? col_name)

        col_value = label_for_x_axis(row["y"].to_i, col_value.to_i, col_name, date_range, row["mon"].to_i)

        processed_result["RECEIVED_TICKETS"][col_name] ||= {}
        processed_result["RESOLVED_TICKETS"][col_name] ||= {}
        processed_result["RECEIVED_TICKETS"][col_name][col_value] ||= 0
        processed_result["RESOLVED_TICKETS"][col_name][col_value] ||= 0

        processed_result["RECEIVED_TICKETS"][col_name][col_value] += row[COLUMN_MAP[:received_count]].to_i
        processed_result["RESOLVED_TICKETS"][col_name][col_value] += row[COLUMN_MAP[:resolved_count]].to_i
      end
    end
    pad_result_with_complete_time_range
    # pad_result_with_total_and_avg_tickets
  end

  def general_and_week_trend_data rec_metric, res_metric
    res_count, rec_count = 0, 0
    res_week_trend, rec_week_trend = days_of_week, days_of_week
    raw_result.each do |row|
      rec_count += row[COLUMN_MAP[:received_count]].to_i
      res_count += row[COLUMN_MAP[:resolved_count]].to_i
      rec_week_trend[row["dow"]][row["h"]] += row[COLUMN_MAP[:received_avg]].to_f
      res_week_trend[row["dow"]][row["h"]] += row[COLUMN_MAP[:resolved_avg]].to_f
    end

    # Ceil Final average values for week trend calculated in above interations
    ceil_week_trend_averages([rec_week_trend, res_week_trend])

    # rec_busiest_day_and_hours = calculate_busiest_day_and_hours(rec_week_trend)

    processed_result[rec_metric][:general] = {metric_result: rec_count}
    processed_result[rec_metric][:week_trend] = rec_week_trend
    # processed_result[rec_metric][:busiest_day_and_hours] = rec_busiest_day_and_hours

    # res_busiest_day_and_hours = calculate_busiest_day_and_hours(res_week_trend)

    processed_result[res_metric][:general] = {metric_result: res_count}
    processed_result[res_metric][:week_trend] = res_week_trend
    # processed_result[res_metric][:busiest_day_and_hours] = res_busiest_day_and_hours

  end
  
  def calculate_busiest_day_and_hours hash
    busiest_day, busiest_hours, current_sum, max_sum = 0, 0, 0, 0

    hash.each do |day,day_hash|
      current_sum = day_hash.values.sum 
      if current_sum > max_sum
        max_sum     = current_sum  
        busiest_day = day  
      end
    end
  
    busiest_hours_hash,max_sum = {},0
    hash[busiest_day].each{|k,v| busiest_hours_hash.store(k.to_i,v)}
    max_hour    = busiest_hours_hash.values.max
    max_indexes = busiest_hours_hash.select { |k, v| v == max_hour}.keys 

    if max_indexes.length > 1
      for i in max_indexes
        prev_sum, next_sum = 0, 0
        next_sum = busiest_hours_hash[i] + busiest_hours_hash[i+1] if i != 23  
        prev_sum = busiest_hours_hash[i] + busiest_hours_hash[i-1] if i != 0   
    
        if next_sum > max_sum
          start_index, end_index = i, i+1
          max_sum = next_sum
        end
        if prev_sum > max_sum
          start_index, end_index = i-1 , i
          max_sum = prev_sum
        end
      end
      end_index += 1 
    else
      start_index = max_indexes[0]
      end_index   = start_index + 1
    end
    "#{Date::ABBR_DAYNAMES[busiest_day.to_i]}, #{convert_no_to_time(start_index)} - #{convert_no_to_time(end_index)}"  
  end
  
  
  def days_of_week
    day_of_week, hour_of_day = {}, {}
    (0..23).each {|h| hour_of_day[h.to_s]=0}
    (0..6).each {|dow| day_of_week[dow.to_s]=hour_of_day.dup}
    day_of_week
  end

  def ceil_week_trend_averages(metrics)
    metrics.each do |metric|
      metric.each do |dow, result|
        result.each {|hour, value| result[hour] = value.ceil}
      end
    end
  end

  def pad_result_with_total_and_avg_tickets
    ["RECEIVED_TICKETS","RESOLVED_TICKETS"].each do |metric|
      ["doy", "w","mon","qtr", "y"].each do |trend|
        if processed_result[metric][trend]
          
          length = processed_result[metric][trend].size
          total  = processed_result[metric][trend].values.sum
          avg    = total / length
          
          processed_result[metric]["#{trend}_total"] = total
          processed_result[metric]["#{trend}_avg"]   = avg
        end
      end
    end
  end

  # To include days, weeks etc for which count = 0, in ascending order of time. REQUIRED in UI
  def pad_result_with_complete_time_range
    ["RECEIVED_TICKETS","RESOLVED_TICKETS"].each do |metric|
      ["doy", "w","mon","qtr", "y"].each do |trend|
        original_hash, padding_hash     = processed_result[metric][trend], range(trend)
        processed_result[metric][trend] = padding_hash.merge(original_hash){|k, old_val, new_val| old_val + new_val} if original_hash.present?
      end
    end
  end

  #converting no to time in readable format - 23 => 11pm
  def convert_no_to_time h
    p, l = h.divmod(12)
    "#{l.zero? ? 12 : l} #{p.zero? ? "a" : "p"}m"
  end

end
