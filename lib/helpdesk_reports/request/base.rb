class HelpdeskReports::Request::Base

  attr_accessor :req_params

  def list_query?
    req_params[:list]
  end

  def bucket_query?
    req_params[:bucket]
  end

  def time_trend_query?
    req_params[:time_trend]
  end

end
