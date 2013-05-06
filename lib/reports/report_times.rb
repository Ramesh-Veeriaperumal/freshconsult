module Reports
	module ReportTimes

	def start_date(zone = true)
    t = zone ? Time.zone : Time
    parse_from_date ? t.parse(parse_from_date).strftime('%Y-%m-%d %H:%M:%S') :
      (t.now.ago 30.day).beginning_of_day.strftime('%Y-%m-%d %H:%M:%S')
  end
  
  def end_date(zone = true)
    t = zone ? Time.zone : Time
    parse_to_date ? t.parse(parse_to_date).strftime('%Y-%m-%d %H:%M:%S') : 
          t.now.beginning_of_day.strftime('%Y-%m-%d %H:%M:%S')
  end
  
  def parse_from_date
    (params[:date_range].split(" - ")[0]) || params[:date_range] unless params[:date_range].blank?
  end
  
  def parse_to_date
    (params[:date_range].split(" - ")[1]) || params[:date_range] unless params[:date_range].blank?
  end
  
  def previous_start
    distance_between_dates =  Time.zone.parse(end_date) - Time.zone.parse(start_date)
    prev_start = Time.zone.parse(previous_end) - distance_between_dates
    prev_start.beginning_of_day.strftime('%Y-%m-%d %H:%M:%S')
  end
  
  def previous_end
    (Time.zone.parse(start_date).ago 1.day).beginning_of_day.strftime('%Y-%m-%d %H:%M:%S')
  end

  def set_time_range(prev_time = false)
    @start_time = prev_time ? previous_start : start_date
    @end_time = prev_time ? previous_end : end_date  
  end

  def end_time
    Time.zone.parse(@end_time).end_of_day
  end

	end
end