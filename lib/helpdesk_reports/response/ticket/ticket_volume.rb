class HelpdeskReports::Response::Ticket::TicketVolume < HelpdeskReports::Response::Ticket::Base

  private

  def process_metric
    processed_result["RECEIVED_TICKETS"], processed_result["RESOLVED_TICKETS"] = {}, {}
    general_and_week_trend_data("RECEIVED_TICKETS", "RESOLVED_TICKETS")
    raw_result.each do |row|
      next if row[COLUMN_MAP[:benchmark]] == "f"

      row.each do |col_name,col_value|
        next if (AVOIDABLE_COLUMNS.include? col_name)

        col_value = label_for_x_axis(row["y"].to_i, col_value.to_i, col_name, date_range) if trend_column? col_name

        processed_result["RECEIVED_TICKETS"][col_name] ||= {}
        processed_result["RESOLVED_TICKETS"][col_name] ||= {}
        processed_result["RECEIVED_TICKETS"][col_name][col_value] ||= 0
        processed_result["RESOLVED_TICKETS"][col_name][col_value] ||= 0

        processed_result["RECEIVED_TICKETS"][col_name][col_value] += row[COLUMN_MAP[:received_count]].to_i
        processed_result["RESOLVED_TICKETS"][col_name][col_value] += row[COLUMN_MAP[:resolved_count]].to_i
      end
    end
    pad_result_with_complete_time_range
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

    processed_result[rec_metric][:general] = {metric_result: rec_count}
    processed_result[rec_metric][:week_trend] = rec_week_trend

    processed_result[res_metric][:general] = {metric_result: res_count}
    processed_result[res_metric][:week_trend] = res_week_trend
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

  # To include days, weeks etc for which count = 0, in ascending order of time. REQUIRED in UI
  def pad_result_with_complete_time_range
    ["RECEIVED_TICKETS","RESOLVED_TICKETS"].each do |metric|
      ["doy", "w","mon","qtr", "y"].each do |trend|
        original_hash, padding_hash     = processed_result[metric][trend], range(trend)
        processed_result[metric][trend] = padding_hash.merge(original_hash){|k, old_val, new_val| old_val + new_val} if original_hash.present?
      end
    end
  end

end
