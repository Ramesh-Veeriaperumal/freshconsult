class Integrations::TimeSheetsSync 

  def self.applications
    [Integrations::Constants::APP_NAMES[:freshbooks],Integrations::Constants::APP_NAMES[:workflow_max]]
  end

  def self.update(time_entry)
    applications.each do |app_key|
      installed_app = Integrations::InstalledApplication.with_name(app_key)
      next if installed_app.blank?  
      Integrations::TimeSheetsSync.send(app_key,installed_app.first,time_entry) unless time_entry.blank?
    end
  end

  def self.freshbooks(inst_app,timeentry)
    integrated_resource = timeentry.integrated_resources.find_by_installed_application_id(inst_app)
    return if integrated_resource.blank?
    domain = inst_app.configs[:inputs]['api_url'].split('//')[1]
    key = inst_app.configs[:inputs]['api_key']
    params = { :domain => domain, :ssl_enabled => "true", :content_type => "application/xml", :accept_type => "application/xml", :username => key, :password => 'X' }
    params[:body] = FRESHBOOKS_UPDATE_REQ.render('time_entry_id' => integrated_resource.remote_integratable_id, 'hours' => timeentry.hours, 'notes' => timeentry.note)
    response = hrp_request(params,"post","FRESHBOOKS_UPDATE_REQ")
  end

  def self.workflow_max(inst_app,timeentry)
    integrated_resource = timeentry.integrated_resources.find_by_installed_application_id(inst_app)
    return if integrated_resource.blank?
    domain = "api.workflowmax.com" #a global api access url 
    apikey = auth_keys(inst_app)
    params = { :domain => domain, :ssl_enabled => "true", :content_type => "application/xml", :accept_type => "application/xml" }
    wfm_time_entry = wfm_fetch_timeentry(params,apikey,integrated_resource.remote_integratable_id)
    minutes = (timeentry.hours.to_f*60).ceil
    wfm_time_entry.merge!('time_entry_id'=>integrated_resource.remote_integratable_id,'hours'=> "#{minutes}",'notes'=>timeentry.note)
    wfm_update_timeentry(params,apikey,wfm_time_entry)
  end

  private

    def self.hrp_request(params,method,oper)
      hrp = HttpRequestProxy.new
      requestParams = { :method => method, :user_agent => "_" }
      response = hrp.fetch_using_req_params(params,requestParams)
      Rails.logger.debug "HttpProxy Request Error:: #{oper}:: #{response[:status]}" unless(response[:status]!~ /^2/)
      response
    end
    
    def self.auth_keys(installed_app)
      apikey = installed_app.configs[:inputs]['api_key']
      account_key = installed_app.configs[:inputs]['account_key']
      return "?apiKey=#{apikey}&accountKey=#{account_key}" #authentication part 
    end

    def self.wfm_fetch_timeentry(params,auth_keys,remote_integratable_id)
      rest_url = "time.api/get/#{remote_integratable_id}"+auth_keys
      params.merge!({:rest_url=>rest_url})
      response = hrp_request(params,"get","WFM_GET_TIME")
      parse_wfm_response(response)
    end

    def self.wfm_update_timeentry(params,auth_keys,wfm_time_entry)
      rest_url = "time.api/update"+auth_keys
      params.merge!({:rest_url=>rest_url})
      params[:body] = WFM_UPDATE_REQ.render(wfm_time_entry)
      hrp_request(params,"put","WFM_UPDATE_TIME")
    end

    def self.parse_wfm_response(response)
      xml = Nokogiri::XML(response[:text])
      date = xml.css("Date").text
      date =  Time.iso8601(date).strftime('%Y%m%d')
      wfm_time_entry = {'staff_id'=>xml.css("Time Staff ID").text,'task_id' => xml.css("Time Task ID").text,'job_id' => xml.css("Time Job ID").text,'date'=>date}
    end

    #Request Templates for the update operations on the third party apps.
    FRESHBOOKS_UPDATE_REQ =  Liquid::Template.parse('<?xml version="1.0" encoding="utf-8"?><request method="time_entry.update"><time_entry><time_entry_id>{{time_entry_id}}</time_entry_id><hours>{{hours}}</hours><notes><![CDATA[{{notes}}]]></notes></time_entry></request>')
  
    WFM_UPDATE_REQ = Liquid::Template.parse('<Timesheet><ID>{{time_entry_id}}</ID><Job>{{job_id}}</Job><Task>{{task_id}}</Task><Staff>{{staff_id}}</Staff><Date>{{date}}</Date><Minutes>{{hours}}</Minutes><Note><![CDATA[{{notes}}]]></Note></Timesheet>')

end
