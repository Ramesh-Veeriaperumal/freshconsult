class Dashboard::GlanceCurrent < Dashboard

  METRIC = "DASHBOARD_GLANCE_TIME_TREND"

  def initialize params
    @req_params = params
    format_params
  end

  def fetch_results
    Dashboard::RedshiftRequester.new(@req_params).fetch_records    
  end

  def fetch_total_results_for_admin
    @req_params[:time_trend_conditions] = []
    @req_params[:time_trend]            = false
    @req_params[:group_by]              = []
    @req_params.deep_dup
  end

  def fetch_total_results_for_supervisor
    @req_params[:time_trend_conditions] = []
    @req_params[:time_trend]            = false
    @req_params[:group_by]              = []
    @req_params.deep_dup
  end

  def fetch_results_by_user
    @req_params[:time_trend_conditions]   = ["doy", "dow"]
    @req_params[:date_range]              = date_range_per_month
    @req_params.deep_dup
  end

  def fetch_total_results_by_user
    @req_params[:time_trend_conditions] = []
    @req_params[:time_trend]            = false
    month_params = @req_params.deep_dup
    @req_params[:date_range]              = date_range_per_week
    week_params = @req_params.deep_dup
    [month_params, week_params]
  end

  private

  def date_range
    redshift_custom_date_format Time.zone.now.beginning_of_day
  end

  def date_range_per_month
    redshift_custom_date_format ([Time.zone.now.beginning_of_month, Time.zone.now.end_of_month])
  end

  def date_range_per_week
    redshift_custom_date_format ([Time.now.beginning_of_week, Time.now.end_of_week.to_date])
  end

  def format_params
    @req_params[:metric]                  = METRIC
    @req_params[:time_trend]              = true
    @req_params[:time_trend_conditions]   = ["h"]
    @req_params[:reference]               = false
    @req_params[:date_range]              = date_range
  end

end