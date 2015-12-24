class HelpdeskReports::Request::Base

  attr_accessor :req_params, :url

  def request    
    begin
      response = RestClient.post url, req_params.to_json, :content_type => :json, :accept => :json
      JSON.parse(response.body)
    rescue => e
      {"errors" => e.inspect}     
    end   
  end

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
