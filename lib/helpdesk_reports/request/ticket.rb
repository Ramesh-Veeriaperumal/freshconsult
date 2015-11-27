class HelpdeskReports::Request::Ticket < HelpdeskReports::Request::Base
  
  include TicketConstants
  include HelpdeskReports::Constants::Ticket
  include HelpdeskReports::Util::Ticket

  attr_accessor :metric, :query_type

  def initialize params
    @url        = ReportsAppConfig::TICKET_REPORTS_URL
    @req_params = params
    @metric     = params[:metric]
    @query_type = set_query_type # list or bucket or simple, NECESSARY for result parsing
  end

  def build_request
    req_params.merge!(account_id: Account.current.id)
    add_bucketing_condition unless req_params[:bucket_conditions].blank?
    add_time_zone_condition
    
    # building list_conditions on trend_graph at helpkit side
    build_list_condition if time_trend_query? and list_query? 
  end

  def fetch_req_params
    req_params
  end

  private

  def set_query_type
    if list_query?
      :list
    elsif bucket_query?
      :bucket
    else
      req_params[:metric].to_sym
    end
  end

  def add_bucketing_condition
    conditions = {}
    req_params[:bucket_conditions].each do |bucket_type|
      buckets = ReportsAppConfig::BUCKET_QUERY[bucket_type.to_sym] 
      bucket_conditions = buckets.map { |e| e.dup } # TO AVOID ALTERING APP CONSTANT *BUCKET_QUERY*
      bucket_conditions.each {|bucket| bucket["label"]  = "#{bucket_type}|#{bucket["label"]}"}
      conditions[bucket_type.to_sym] = bucket_conditions
    end
    req_params.merge!(bucket_conditions: conditions)
  end

  def add_time_zone_condition
    time_zone = Account.current.time_zone
    time_zone = time_zone.present? ? time_zone : DEFAULT_TIME_ZONE
    req_params.merge!(time_zone: time_zone)
  end
  
  def build_list_condition
    trend = req_params[:list_conditions].first["condition"]
    unless trend == "y"
      selected_date = trend == "w" ? req_params[:list_conditions].first["value"].split("-").first : req_params[:list_conditions].first["value"] 
      date  = Date.parse(selected_date)
      year_condition = {
        condition:  "y",
        operator:   "is_in",
        value:      date.year.to_s
      }
      trend_condition = {
        condition: trend,
        operator: "is_in",
        value:   date_part(date, trend).to_s
      }
      # We are using ISO 8601 definition to work with week part of the dates. (In Ruby, Date.cweek follows ISO 8601, Date.strftime("%W") does NOT follow)
      # By definition (ISO 8601), the first week of a year contains January 4 of that year. (The ISO-8601 week starts on Monday.) 
      # In other words, the first Thursday of a year is in week 1 of that year
      # Due to above definiton it can happen that an year has two separate weeks with week number 1, which is an expected behaviour
      # and in any such case, week number 1 occurring in December is actually week number 1 of next year.
      # For example, Date.parse("29 Dec, 2014").cweek gives 1 as result, here its the 1st week of 2015 and not 2014.
      # below piece of code is written in this way because for date = 29 Dec, 2014 (and similar cases) date.year = 2014 and date.cweek = 1
      # it is logically correct when considered separately, but not when joined together (year = 2014 and week = 1) which will become week = 1 
      # occurring in January 2014.
      
      # Since week trend is limited to show maximum of 31 week, we can safely remove year condition in case of above described
      # special case (week = 1 occurring in December).
      
      # IN FUTURE IF WE EXTEND THIS LIMIT, THIS WOULD BE AN AMBIGIOUS CASE FOR LIST QUERY ON A SPECIFIC WEEK.
      if trend == "w" and date.cweek == 1 and date.mon > 1
        req_params[:list_conditions] =  [trend_condition]
      else
        req_params[:list_conditions] = [year_condition, trend_condition]
      end
    end
  end

end
