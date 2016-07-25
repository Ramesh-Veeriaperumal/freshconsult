class HelpdeskReports::Request::Ticket
  include TicketConstants
  include HelpdeskReports::Constants
  include HelpdeskReports::Util::Ticket

  attr_accessor :req_params, :metric, :query_type, :end_date

  def initialize params, report_type
    @req_params = params
    @metric     = params[:metric]
    @query_type = set_query_type # list or bucket or simple, NECESSARY for result parsing
    @report_type = report_type
  end

  def build_request
    req_params.merge!(account_id: Account.current.id)
    req_params.merge!(report_type: @report_type)
    req_params.merge!(account_plan: current_account_plan)
    req_params.merge!(account_domain: Account.current.full_domain)
    add_bucketing_condition unless req_params[:bucket_conditions].blank?
    add_time_zone_condition
    
    # building list_conditions on trend_graph at helpkit side
    build_list_condition if time_trend_query? and list_query? 
  end

  #For trial account, sending trial as plan.
  def current_account_plan
    Account.current.subscription.state == "trial" ? :trial : Account.current.plan_name
  end

  def fetch_req_params
    req_params
  end

  private

  def list_query?
    req_params[:list]
  end

  def bucket_query?
    req_params[:bucket]
  end

  def time_trend_query?
    req_params[:time_trend]
  end

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
    time_zone = Account.current.time_zone || DEFAULT_TIME_ZONE
    req_params.merge!(time_zone: time_zone)
  end
  
  def build_list_condition
    trend = req_params[:list_conditions].first["condition"]
    if req_params[:metric] == "UNRESOLVED_TICKETS"
      dates      = req_params[:date_range].split("-")
      start_date = DateTime.parse(dates[0])
      @end_date  = dates.length > 1 ? DateTime.parse(dates[1]) : start_date
      value      = req_params[:list_conditions].first["value"]
      req_params[:date_range] = generating_end_value(trend,value)
      req_params[:time_trend] = false
      req_params[:time_trend_conditions] = []
    else
      unless trend == "y"
        selected_date = trend == "w" ? req_params[:list_conditions].first["value"].split("-").first : req_params[:list_conditions].first["value"] 
        date  = Date.parse(selected_date)
        year_condition = {
          condition:  "y",
          operator:   "eql",
          value:      date.year.to_s
        }
        trend_condition = {
          condition: trend,
          operator: "eql",
          value:   date_part(date, trend).to_s
        }
        req_params[:list_conditions] = ["doy","w"].include?(trend) ? [trend_condition] : [year_condition, trend_condition]
      end
    end 
  end

    def generating_end_value trend, label
    case trend
      when "doy"
        return label
      when "w"
        return label.split(" - ").second
      when "mon"
        date = Date.parse(label).end_of_month
      when "qtr"
        date = Date.parse(label).end_of_month
      when "y"
        date = Date.ordinal(label.to_i).end_of_year
      end
      date = date < end_date ? date : end_date
      date.strftime('%d %b, %Y')
  end

end
