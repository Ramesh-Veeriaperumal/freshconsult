module IntegrationServices::Services
  module Fullcontact
    class CompanyResource < FullcontactResource

      def company_instance_url
        @service.api_url + "company/lookup.json"
      end

      def fetch_company
        @current_company = @service.payload[:act_on_object]
        return {:status => 400, :message => I18n.t(:'integrations.fullcontact.message.domain_absent')} unless current_company.company_domains.present?
        value = current_company.company_domains.first.domain
        params = { "domain" => value, "apiKey" => @service.configs["api_key"] }
        params.merge!(webhook_params) if @service.payload[:webhook_flag]
        response = http_get company_instance_url, params 
        process_response response
      end

      def update_company
        begin
          selected_fc_fields = @service.configs["company"]["fc_field"]
          @service.configs["company"]["fd_field"].each_with_index do |field, index|
            if current_company.send(field).blank? and company_response.send(selected_fc_fields[index]).present?
              value = company_response.send(selected_fc_fields[index])
              current_company.send(field + "=" , value)
            end
          end
          current_company.save!
        rescue Exception => e
          Rails.logger.debug "Exception in Fullcontact Integration :: #{e.to_s} :: #{e.backtrace.join("\n")}"
          NewRelic::Agent.notice_error(e.to_s)
        end
      end

      def get_company_diff
        diff_array = [] #array of {fc_field_name => [fd_display_label, fd_val, fc_val, fc_field_type]}
        @service.configs["company"]["fc_field"].each_with_index do |fc_field, index|
          fd_field = @service.configs["company"]["fd_field"][index]
          fc_val = company_response.send(fc_field)
          next unless company_fields_list.include?fd_field and fc_val.present?
          fd_val = current_company.send(fd_field)
          fc_field_type = FC_COMPANY_DATA_TYPES[FC_COMPANY_FIELDS_HASH[fc_field]]
          case fd_field
          when "name"
            if Account.current.companies.exists?(:name => fc_val)
              fd_val += " (#{I18n.t(:'integrations.fullcontact.message.company_exists', :name => fc_val)})" 
            end
            diff_array << { fc_field => [column_label("company", fd_field), fd_val, fc_val, fc_field_type] } if ( fd_val.present? and fc_val.downcase != fd_val.downcase)
          else
            diff_array << { fc_field => [column_label("company", fd_field), fd_val, fc_val, fc_field_type] } if (fc_val != fd_val)
          end
        end
        diff_array
      end

      def update_fields
        message = I18n.t(:'integrations.fullcontact.message.update_success')
        @service.payload[:field_values].each do |fc_field, value|
          index = @service.configs["company"]["fc_field"].find_index(fc_field.to_s)
          name = @service.configs["company"]["fd_field"][index]
          next unless company_fields_list.include?name and value.present?
          if (name == "name" and Account.current.companies.exists?(:name => value))
            message = I18n.t(:'integrations.fullcontact.message.company_exists', :name => value)
            next
          end
          current_company.send(name + '=', value)
        end
        current_company.save!
        {:status => 200, :message => message}
      end

    private

      def process_response response
        if response.status.eql? 422
          return {:status => 422, :message => I18n.t(:'integrations.fullcontact.message.invalid_company_fields')}
        end
        super
      end

      def company_fields_list
        Account.current.company_form.fields.collect{|field| field["name"]}
      end

      def webhook_params
        { 
          "webhookUrl" => "https://#{Account.current.full_domain}/integrations/fullcontact/callback", 
          "webhookId" => "company:#{current_company.id}"
        }
      end

      def current_company
        @current_company ||= Account.current.companies.find(@service.payload[:company_id])
      end

      def company_response
        @company_response ||= IntegrationServices::Services::Fullcontact::Formatter::CompanyFormatter.new(@service.payload[:result])
      end

    end
  end
end
