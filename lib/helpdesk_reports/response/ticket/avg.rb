class HelpdeskReports::Response::Ticket::Avg < HelpdeskReports::Response::Ticket::Base

  include HelpdeskReports::Util::Ticket
  
  private

  def process_metric
    helper_hash = {}

    calculate_general_avg_data
    raw_result.each do |row|
      next if row[COLUMN_MAP[:benchmark]] == "f"
      row.each do |column,value|
        next if (AVOIDABLE_COLUMNS.include? column)
          
        value = label_for_x_axis(row["y"].to_i, row["doy"].to_i, value.to_i, column, date_range) if trend_column? column
        
        processed_result[column] ||= {}
        helper_hash[column] ||= {}

        processed_result[column][value] ||= 0
        helper_hash[column][value] ||= {:avg => 0, :count => 0}

        processed_result[column][value]    = aggregate_avg(helper_hash[column][value], row)
        helper_hash[column][value][:avg]   = processed_result[column][value]
        helper_hash[column][value][:count] += row[COLUMN_MAP[:count]].to_i
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
        :metric_result    => formatted_duration(current_avg[:avg]),
        :diff_percentage  => diff_percentage
      }
    else
      final_avg = {:avg => 0.0, :count => 0}
      raw_result.each do |row|
        final_avg[:avg]   = aggregate_avg(final_avg, row)
        final_avg[:count]+= row[COLUMN_MAP[:count]].to_i
      end      
      processed_result[:general] = {
        :metric_result => formatted_duration(final_avg[:avg])
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
    resulting_avg ? resulting_avg.round(2) : 0.0
  end

  # Sending averages as integers (in minutes) since JS lib used to render charts needs integer 
  # values to plot graph. Graphs are plotted only for group_by fields or trends (days, weeks etc)
  # hence only corresponding values are integer. Average for Metrics is sent in dd:hh:mm format
  # def convert_time_to_interger # TO DO MAKE IT GENERIC
  #   processed_result.each do |column_name, values|
  #     next if column_name == :general
  #     values.each do |label,v| 
  #       values[label] = values[label].to_i
  #     end
  #   end
  # end

  def pad_result_with_complete_time_range
    ["doy", "w","mon","qtr", "y"].each do |trend|
      original_hash, padding_hash     = processed_result[trend], range(trend)
      processed_result[trend] = padding_hash.merge(original_hash){|k, old_val, new_val| old_val + new_val} if original_hash.present?
    end
  end

  def label_for_x_axis year, doy, point, trend, date_range
    case trend
      when "doy"
        Date.ordinal(year, point).strftime('%s').to_i * 1000
      when "w"
        week_to_date(point, year, doy, date_range).to_i * 1000
      when "y"
        Date.ordinal(point).strftime('%s').to_i * 1000
      when "qtr"
        Date.new(year, point * 3).beginning_of_quarter.strftime('%s').to_i * 1000
      when "mon"
        Date.new(year, point).strftime('%s').to_i * 1000
    end
  end

  def week_to_date week, year, doy, date_range
    dates           = date_range.split("-")
    actually_date   = Date.ordinal(year, doy)
    week_start_date = Date.commercial(year, week,1)
    week_end_date   = Date.commercial(year, week,7)
    if actually_date >= week_start_date && actually_date <= week_end_date
        week_start_date.strftime('%s')
    else
        Date.commercial(year+1,week).strftime('%s')
    end
  end

    def range trend
    dates = date_range.split("-")
    start_day = Date.parse(dates.first)
    end_day = dates.length > 1 ?  Date.parse(dates.second) : start_day
    padding_hash = {}

    if trend == "y" 
      (start_day.year..end_day.year).each do |i| 
          i = label_for_x_axis(i, 0, i, trend, date_range)
          padding_hash[i] = 0 
      end
    elsif trend == "w"
      (start_day.year..end_day.year).each do |y|
        start_point  = (start_day.year == y) ? date_part(start_day, trend) : 1
        end_point = (end_day.year == y) ? date_part(end_day, trend) : trend_max_value(trend, y)

        (start_point..end_point).each do |i|
          doy  = Date.commercial(y, i).yday
          year = Date.commercial(y, i).year
          i = label_for_x_axis(year, doy, i, trend, date_range)
          padding_hash[i] = 0
        end
      end
    else
      (start_day.year..end_day.year).each do |y|
        start_point  = (start_day.year == y) ? date_part(start_day, trend) : 1
        end_point = (end_day.year == y) ? date_part(end_day, trend) : trend_max_value(trend, y)

        (start_point..end_point).each do |i|
          i = label_for_x_axis(y, 0, i, trend, date_range)
          padding_hash[i] = 0
        end
      end
    end
    padding_hash
  end

end
