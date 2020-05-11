class Monitoring::PagerDuty

    # Path to pager duty config. Expects an +service_key+ and +event_url+
    mattr_accessor :config_yml

    @@config_yml = "#{Rails.root}/config/pager_duty.yml"

    class << self
        #incident_key(String) - Unique incident key
        # details(Hash) - { 
        #  "description": "FAILURE for production/HTTP on machine srv01.acme.com",
        #  "details": {
        #    "ping time": "1500ms",
        #    "load avg": 0.75
        #  }
        def trigger_incident(incident_key,details)
            params = { :service_key => config['service_key'], :incident_key => incident_key }
            params.merge! details
            trigger_event("trigger",params)
        end

        def config
            @@config ||= begin 
                config = YAML::load_file(config_yml)
                config.has_key?(Rails.env) ? config[Rails.env] : config
            end
        end

        protected
            def trigger_event(event_type, params = {})
                params.merge!({:event_type => event_type})
                url = URI.parse config['event_url']
                http = Net::HTTP.new(url.host, url.port)
                req = Net::HTTP::Post.new(url.request_uri)
                req.body = params.to_json
                res = http.request(req)
                case res
                when Net::HTTPSuccess, Net::HTTPRedirection
                  JSON.parse(res.body)
                else
                  res.error!
                end
            end
            
    end
end
