class Integrations::TimeSheetsSync 

  def self.applications
    [Integrations::Constants::APP_NAMES[:freshbooks], Integrations::Constants::APP_NAMES[:workflow_max], Integrations::Constants::APP_NAMES[:harvest], Integrations::Constants::APP_NAMES[:quickbooks]]
  end

  def self.update(time_entry, user)
    applications.each do |app_key|
      installed_app = Account.current.installed_applications.with_name(app_key)
      next if installed_app.blank?  
      Integrations::TimeSheetsSync.send(app_key, installed_app.first, time_entry, user) unless time_entry.blank?
    end
  end

  def self.freshbooks(inst_app,timeentry,user)
    integrated_resource = timeentry.integrated_resources.find_by_installed_application_id(inst_app)
    return if integrated_resource.blank?
    domain = inst_app.configs[:inputs]['api_url'].split('//')[1]
    key = inst_app.configs[:inputs]['api_key']
    params = { :domain => domain, :ssl_enabled => "true", :content_type => "application/xml", :accept_type => "application/xml", :username => key, :password => 'X' }
    notes = Liquid::Template.parse(inst_app.configs[:inputs]['freshbooks_note']).render('ticket'=>timeentry.workable)
    params[:body] = FRESHBOOKS_UPDATE_REQ.render('time_entry_id' => integrated_resource.remote_integratable_id, 'hours' => timeentry.hours, 'notes' => "#{timeentry.note}\n#{notes}")
    response = hrp_request(params,"post","FRESHBOOKS_UPDATE_REQ")
  end

  def self.workflow_max(inst_app,timeentry,user)
    integrated_resource = timeentry.integrated_resources.find_by_installed_application_id(inst_app)
    return if integrated_resource.blank?
    domain = "api.workflowmax.com" #a global api access url 
    apikey = auth_keys(inst_app)
    params = { :domain => domain, :ssl_enabled => "true", :content_type => "application/xml", :accept_type => "application/xml" }
    wfm_time_entry = wfm_fetch_timeentry(params,apikey,integrated_resource.remote_integratable_id)
    minutes = (timeentry.hours.to_f*60).ceil
    notes = Liquid::Template.parse(inst_app.configs[:inputs]['workflow_max_note']).render('ticket'=>timeentry.workable)
    wfm_time_entry.merge!('time_entry_id'=>integrated_resource.remote_integratable_id,'hours'=> "#{minutes}",'notes'=>"#{timeentry.note}\n#{notes}")
    wfm_update_timeentry(params,apikey,wfm_time_entry)
  end

  def self.harvest(inst_app,timeentry,user)
    integrated_resource = timeentry.integrated_resources.find_by_installed_application_id(inst_app)
    return if integrated_resource.blank?
    domain = inst_app.configs[:inputs]['domain'] #fetching domain for installed app
    user_credential = inst_app.user_credentials.find_by_user_id(user)
    rest_url = "daily/update/#{integrated_resource.remote_integratable_id}"
    params = harvest_params(user_credential,timeentry,rest_url)
    params.merge!(:domain=>domain)
    response = hrp_request(params,"post","HARVEST_UPDATE_REQ")
  end

  def self.quickbooks(inst_app, timeentry, user)
    integrated_resource = timeentry.integrated_resources.find_by_installed_application_id(inst_app)
    return if integrated_resource.blank?
    params = quickbooks_params('post', "v3/company/" + inst_app.configs[:inputs]['company_id'] + "/timeactivity")
    quickbooks_timeentry = quickbooks_fetch_timeentry(inst_app, integrated_resource.remote_integratable_id)
    quickbooks_timeentry["hours"] = timeentry.hours.to_f.floor
    quickbooks_timeentry["minutes"] = ((timeentry.hours.to_f * 60) % 60).round
    quickbooks_timeentry["notes"] = quickbooks_timeentry["Description"].to_json
    params[:body] = QUICKBOOKS_UPDATE_REQ.render(quickbooks_timeentry)
    response = hrp_request(params, "post", "QUICKBOOKS_UPDATE_REQ")
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

    def self.quickbooks_fetch_timeentry(installed_app, remote_integratable_id)
      rest_url = "v3/company/" + installed_app.configs[:inputs]['company_id'] + "/timeactivity/" + remote_integratable_id
      params = quickbooks_params('get', rest_url)
      response = hrp_request(params, "get", "QUICKBOOKS_UPDATE_REQ")
      parse_quickbooks_response(response)
    end

    def self.parse_quickbooks_response(response)
      JSON.parse(response[:text])["IntuitResponse"]["TimeActivity"]
    end

    def self.harvest_params(credential,timeentry,rest_url)
      password = Base64.decode64(credential.auth_info[:password])
      params = {:ssl_enabled => "true", :rest_url=>rest_url, :content_type => "application/xml", :accept_type => "application/xml", :username => credential.auth_info[:username], :password => password }
      params[:body] = HARVEST_UPDATE_REQ.render('hours'=>timeentry.hours)
      params
    end

    def self.quickbooks_params(method, rest_url)
      params = {
        :ssl_enabled => true,
        :rest_url => rest_url,
        :auth_type => "OAuth1",
        :domain => "https://quickbooks.api.intuit.com",
        :method => method,
        :app_name => "quickbooks"
      }
      params
    end

    #Request Templates for the update operations on the third party apps.
    FRESHBOOKS_UPDATE_REQ =  Liquid::Template.parse('<?xml version="1.0" encoding="utf-8"?><request method="time_entry.update"><time_entry><time_entry_id>{{time_entry_id}}</time_entry_id><hours>{{hours}}</hours><notes><![CDATA[{{notes}}]]></notes></time_entry></request>')
  
    WFM_UPDATE_REQ = Liquid::Template.parse('<Timesheet><ID>{{time_entry_id}}</ID><Job>{{job_id}}</Job><Task>{{task_id}}</Task><Staff>{{staff_id}}</Staff><Date>{{date}}</Date><Minutes>{{hours}}</Minutes><Note><![CDATA[{{notes}}]]></Note></Timesheet>')

    HARVEST_UPDATE_REQ = Liquid::Template.parse('<request><hours>{{hours}}</hours></request>')

    QUICKBOOKS_UPDATE_REQ = Liquid::Template.parse('{"TxnDate" : "{{TxnDate}}", "NameOf" : "Employee", "EmployeeRef" : {"value" : {{EmployeeRef}}}, "CustomerRef" : {"value" : {{CustomerRef}}}, "BillableStatus" : "Billable", "HourlyRate" : "0", "Hours" : {{hours}}, "Minutes" : {{minutes}}, "Id" : {{Id}}, "SyncToken" : {{SyncToken}}, "Description" : {{notes}}}')

end
