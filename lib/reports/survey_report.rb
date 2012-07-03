module Reports::SurveyReport
	include Reports::ActivityReport
  
  def start_date
    parse_from_date.nil? ? (Time.zone.now.ago 30.day).beginning_of_day.to_s(:db) : 
        Time.zone.parse(parse_from_date).beginning_of_day.to_s(:db) 
  end
  
  def end_date
    parse_to_date.nil? ? Time.zone.now.end_of_day.to_s(:db) : 
        Time.zone.parse(parse_to_date).end_of_day.to_s(:db)
  end
  
  def parse_from_date
    (!params[:date_range].blank? && params[:date_range].split(" - ")[0]) || params[:date_range]
  end
  
  def parse_to_date
    (!params[:date_range].blank? && params[:date_range].split(" - ")[1]) || params[:date_range]
  end
end