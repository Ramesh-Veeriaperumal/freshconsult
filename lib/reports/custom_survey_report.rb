module Reports::CustomSurveyReport
	include Reports::ActivityReport
  
  def start_date
    parse_from_date.nil? ? (Time.zone.now.ago 30.day).beginning_of_day.to_s(:db) : 
       Time.zone.parse(Time.at(parse_from_date.to_i).to_s).beginning_of_day.to_s(:db) 
  end
  
  def end_date
    parse_to_date.nil? ? Time.zone.now.end_of_day.to_s(:db) : 
       Time.zone.parse(Time.at(parse_to_date.to_i).to_s).end_of_day.to_s(:db) 
  end
  
  def parse_from_date
    (!params[:date_range].blank? && params[:date_range].split("-")[0]) || params[:date_range]
  end
  
  def parse_to_date
    (!params[:date_range].blank? && params[:date_range].split("-")[1]) || params[:date_range]
  end
end