module Reports::CustomSurveyReport
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
    unless params[:date_range].blank?
      fromDate = params[:date_range].split("-")[0]
      return (fromDate[0,2] + "-" + fromDate[2,2] + "-" + fromDate[4,4])
    end
  end
  
  def parse_to_date
    unless params[:date_range].blank?
      toDate = params[:date_range].split("-")[1]
      return (toDate[0,2] + "-" + toDate[2,2] + "-" + toDate[4,4])
    end
  end
end