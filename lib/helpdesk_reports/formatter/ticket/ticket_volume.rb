class HelpdeskReports::Formatter::Ticket::TicketVolume

  include HelpdeskReports::Util::Ticket
  include HelpdeskReports::Helper::ReportsHelper

  TIME_TREND_METRICS = ["received_tickets","resolved_tickets","all_unresolved_tickets"]

  attr_accessor :overall, :rec_res_benchmark, :previous_unresolved_benchmark, :current_unresolved_benchmark, :processed_result, :report_type, :start_date, :end_date

  def initialize data, args = {}
    @overall              = data['RECEIVED_RESOLVED_TICKETS']
    @rec_res_benchmark    = data['RECEIVED_RESOLVED_BENCHMARK']
    @previous_unresolved_benchmark = data['UNRESOLVED_PREVIOUS_BENCHMARK']
    @current_unresolved_benchmark = data['UNRESOLVED_CURRENT_BENCHMARK']
    @processed_result     = {}
    @report_type = :ticket_volume
    dates        = args[:date_range].split("-")
    @start_date  = DateTime.parse(dates[0])
    @end_date    = dates.length > 1 ? DateTime.parse(dates[1]) : start_date
  end

  def perform
    return {} if (current_unresolved_benchmark[0]["unresolved_count"].to_i == 0 && overall.empty?)
    process_metric
    general_and_week_trend_data
    populate_derived_metrics_with_zero_vals
    @overall = processed_result
    calculate_derived_metrics
    manipulating_extra_details
    overall
  end

  def process_metric
    return queried_metrics_with_zero_vals if overall.empty?
    (queried_metrics.keys + derived_metrics).each { |metric| processed_result[metric] = {} }
    overall.each do |row|
      next if row[COLUMN_MAP[:benchmark]] == "f"

      row.each do |col_name,col_value|
        next if (AVOIDABLE_COLUMNS.include? col_name)
        col_value = label_for_x_axis(row["y"].to_i, col_value, col_name)
        queried_metrics.each do |metric, redshift_column|
          processed_result[metric][col_name] ||= Hash.new(0)
          processed_result[metric][col_name][col_value] += row[redshift_column.to_s].to_i
        end
        processed_result["NEW_RESOLVED_TICKETS"][col_name] ||= Hash.new(0)
        processed_result["NEW_RESOLVED_TICKETS"][col_name][col_value] += row["#{col_name}_new_resolved_count"].to_i
      end
    end
    pad_result_with_complete_time_range
  end

  def calculate_derived_metrics
    trends_to_show.each do |trend|
      if(overall['ALL_UNRESOLVED_TICKETS'][trend])
        unresolved = current_unresolved_benchmark[0]["unresolved_count"].to_i
        overall['ALL_UNRESOLVED_TICKETS'][trend].keys.reverse.each do |key|
          overall['TOTAL_LOAD'][trend][key] += unresolved
          overall['ALL_UNRESOLVED_TICKETS'][trend][key] += unresolved
          unresolved = (overall['TOTAL_LOAD'][trend][key] + overall['RESOLVED_TICKETS'][trend][key] - overall['RECEIVED_TICKETS'][trend][key] )
        end
      end
      if(overall['NEW_RESOLVED_TICKETS'][trend])
        overall['NEW_RESOLVED_TICKETS'][trend].keys.each do |key|
          overall['NEW_UNRESOLVED_TICKETS'][trend][key] += (overall['RECEIVED_TICKETS'][trend][key] - overall['NEW_RESOLVED_TICKETS'][trend][key])
        end
      end
    end
  end

  def manipulating_extra_details
    current_values , previous_values = {}, {}
    rec_res_benchmark.each do |hash|
      current_values.reverse_merge!(hash) if hash["range_benchmark"] == "t" 
      previous_values.reverse_merge!(hash) if hash["range_benchmark"] == "f" 
    end

    previous_values["all_unresolved_tickets"] = previous_unresolved_benchmark[0]["unresolved_count"]
    current_values["all_unresolved_tickets"]  = current_unresolved_benchmark[0]["unresolved_count"]
    TIME_TREND_METRICS.each do |metric|
      total = current_values[metric].to_f
      extra_details = {
        "total"     => current_values[metric].to_i,
        "diff_perc" => calculate_difference_percentage(previous_values[metric].to_f,current_values[metric].to_f),
      }
      trends_to_show.each do |trend|
        avg = (total/overall[metric.upcase][trend].size).to_i
        extra_details[trend+'_avg'] = avg if overall[metric.upcase][trend]
      end
      overall[metric.upcase] ||= {}
      overall[metric.upcase]["extra_details"] = extra_details
    end
  end

  def calculate_difference_percentage previous_val, current_val
    return NOT_APPICABLE if ( previous_val.to_i == 0 || [previous_val, current_val].include?(NOT_APPICABLE))
    percentage = (current_val.to_f - previous_val.to_f)*100/ previous_val.to_f
    percentage.round
  end

  private

    def general_and_week_trend_data
      counts = Hash.new(0)
      res_week_trend, rec_week_trend = days_of_week, days_of_week
      overall.each do |row|
        queried_metrics.each do |metric, redshift_column|
          counts[metric] += row[redshift_column].to_i
        end
        rec_week_trend[row["dow"]][row["h"]] += row[COLUMN_MAP[:received_avg]].to_f
        res_week_trend[row["dow"]][row["h"]] += row[COLUMN_MAP[:resolved_avg]].to_f
      end

      queried_metrics.each do |metric, redshift_column|
        processed_result[metric][:general] = {metric_result: counts[metric]}
      end

      return if rec_res_benchmark.empty?

      # Ceil Final average values for week trend calculated in above interations
      ceil_week_trend_averages([rec_week_trend, res_week_trend])

      rec_busiest_day_and_hours = calculate_busiest_day_and_hours(rec_week_trend)
      processed_result["RECEIVED_TICKETS"][:week_trend] = rec_week_trend
      processed_result["RECEIVED_TICKETS"][:busiest_day_and_hours] = rec_busiest_day_and_hours

      res_busiest_day_and_hours = calculate_busiest_day_and_hours(res_week_trend)
      processed_result["RESOLVED_TICKETS"][:week_trend] = res_week_trend
      processed_result["RESOLVED_TICKETS"][:busiest_day_and_hours] = res_busiest_day_and_hours
      @overall = processed_result
    end

    def calculate_busiest_day_and_hours hash
      busiest_day = hash.values.collect{|h| h.values.sum}.each_with_index.max[1].to_s
      busy_hours = hash.values.collect{|d| d.max_by{|k,v| v}}
      max_busy = busy_hours.max_by{|a| a[1]}[1]
      busiest_hours = {}
      busy_hours.each_with_index{|b,i| busiest_hours[i.to_s] = b if b[1] == max_busy}
      if busiest_hours.size == 1
        start_index, end_index = [busiest_hours.values.first[0].to_i, busiest_hours.values.first[0].to_i+1]
      else
        #Calculating busiest range by extending the range by (+/-)1 hour and calculating maximum number of tickets
        max_tickets, start_index, end_index = busiest_hours.collect do |k,v|
          [[v[1]+hash[k][(v[0].to_i-1).to_s],v[0].to_i-1,v[0].to_i],[v[1]+hash[k][(v[0].to_i+1).to_s],v[0].to_i,v[0].to_i+1]] unless v[0] == "0" || v[0] == "23"
        end.flatten(1).compact.max
      end
      if(start_index == end_index)
        ["-", "-"]
      else
        [Date::DAYNAMES[busiest_day.to_i], "#{convert_no_to_time(start_index)} - #{convert_no_to_time(end_index)}"]
      end
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
      queried_metrics.keys.each do |metric|
        %w(doy w mon qtr y).each do |trend|
          original_hash, padding_hash     = processed_result[metric][trend], range(trend)
          processed_result[metric][trend] = padding_hash.merge(original_hash){|k, old_val, new_val| old_val + new_val} if original_hash.present?
        end
      end
    end

    #converting no to time in readable format - 23 => 11pm
    def convert_no_to_time h
      p, l = h.to_i.divmod(12)
      "#{l.zero? ? 12 : l} #{p.zero? ? "a" : "p"}m"
    end

    def queried_metrics
      metrics = {
        "RECEIVED_TICKETS"     => :received_count,
        "RESOLVED_TICKETS"     => :resolved_count,
        "NEW_RESOLVED_TICKETS" => :new_resolved
      }

    end

    def derived_metrics
      %w(TOTAL_LOAD ALL_UNRESOLVED_TICKETS NEW_UNRESOLVED_TICKETS)
    end

    def populate_derived_metrics_with_zero_vals
      derived_metrics.each do |metric|
        processed_result[metric] = {}
        trends_to_show.each do |trend|
          processed_result[metric][trend] = range(trend)
        end
      end
    end

    def queried_metrics_with_zero_vals
      queried_metrics.keys.each do |metric|
        processed_result[metric] = {}
        trends_to_show.each do |trend|
          processed_result[metric][trend] = range(trend)
        end
      end
    end

    def trends_to_show
      @trends ||= []
      return @trends unless @trends.empty?
      %w(doy w mon qtr y).zip([1, 7, 30 ,90, 365]).each do |trend,value|
        @trends << trend if(((end_date - start_date).to_i + 1) <= MAX_DATE_RANGE_FOR_TREND[trend])
      end
      @trends = (overall.empty? || overall["RECEIVED_TICKETS"].empty?) ? @trends : (@trends & overall["RECEIVED_TICKETS"].keys)
    end

end
