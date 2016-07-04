module IntegrationServices::Services
  module Fullcontact
    class ContactResource < FullcontactResource
      include ApplicationHelper

      def contact_instance_url
        @service.api_url + "person.json"
      end
      
      def fetch_contact
        @current_contact = @service.payload[:act_on_object]
        if current_contact.email?
          value = current_contact.email
          type = "email"
        elsif current_contact.twitter_id.present?
          value = current_contact.twitter_id
          type = "twitter"
        elsif current_contact.phone? || current_contact.mobile?
          value = current_contact.phone || current_contact.mobile
          type = "phone"
        else
          return {:status => 404, :message => I18n.t(:'integrations.fullcontact.message.seek_field_empty')}
        end

        params = {type => value, "apiKey" => @service.configs["api_key"] }
        params.merge!(webhook_params) if @service.payload[:webhook_flag]
        response = http_get contact_instance_url, params
        process_response response
      end

      def update_contact
        begin
          selected_fc_fields = @service.configs["contact"]["fc_field"]
          @service.configs["contact"]["fd_field"].each_with_index do |field, index|
            case field
            when "avatar"
              add_user_avatar(contact_response.avatar) if current_contact.avatar.nil? and contact_response.avatar.present?
            when "company_name"
              current_contact.company_name = contact_response.organization if current_contact.company.nil? and contact_response.organization.present?
            when "twitter_id"
              value = contact_response.social_profiles[selected_fc_fields[index]] || ""
              next if value.blank? || Account.current.contacts.where(twitter_id: value).first
              current_contact.send(field + "=", value)
            else
              if current_contact.send(field).blank?
                if contact_response.respond_to? selected_fc_fields[index]
                  current_contact.send(field + '=', contact_response.send(selected_fc_fields[index]))
                else
                  value = contact_response.social_profiles[selected_fc_fields[index]] || ""
                  current_contact.send(field + '=', value)
                end
              end
            end
          end
          current_contact.save!
        rescue Exception => e
          Rails.logger.debug "Exception in Fullcontact Integration :: #{e.to_s} :: #{e.backtrace.join("\n")}"
          custom_params = {
            :description => "Exception in Fullcontact Avatar Updation Failure.",
          }
          custom_params.merge!({:params => current_contact.id}) if current_contact
          NewRelic::Agent.notice_error(e.to_s, :custom_params => custom_params)
        end
      end

      def get_contact_diff
        diff_array = [] #array of {fc_field_name => [fd_display_label, fd_val, fc_val, fc_field_type]}
        @service.configs["contact"]["fc_field"].each_with_index do |fc_field, index|
          fd_field = @service.configs["contact"]["fd_field"][index]
          fc_val = contact_response.respond_to?(fc_field) ? contact_response.send(fc_field) : contact_response.social_profiles[fc_field]
          next unless contact_fields_list.include? fd_field and fc_val.present?
          fd_val = current_contact.send(fd_field)
          fc_field_type = FC_CONTACT_DATA_TYPES[FC_CONTACT_FIELDS_HASH[fc_field]]
          case fc_field
          when "avatar"
            diff_array << {"avatar" => ["Avatar", user_avatar(current_contact), contact_response.avatar, "avatar"]} if contact_response.avatar.present?
          when "twitter_id", "organization"
            diff_array << { fc_field => [column_label("contact", fd_field), fd_val, fc_val, fc_field_type] } if ((fd_val || "").downcase != (fc_val || "").downcase)
          else
            diff_array << { fc_field => [column_label("contact", fd_field), fd_val, fc_val, fc_field_type] } if ( fc_val != fd_val)
          end
        end
        diff_array
      end

      def update_fields
        @service.payload[:field_values].each do |fc_field, value|
          index = @service.configs["contact"]["fc_field"].find_index(fc_field.to_s)
          name = @service.configs["contact"]["fd_field"][index]
          next unless contact_fields_list.include? name
          case name
          when "avatar"
            add_user_avatar(value)
          when "company_name"
            current_contact.company_name = value
          when "twitter_id"
            next if value.blank? || Account.current.contacts.find_by_twitter_id(value)
            current_contact.twitter_id = value
          else
            current_contact.send(name + '=', value)
          end
        end
        current_contact.save!
        {:status => 200, :message => I18n.t(:'integrations.fullcontact.message.update_success')}
      end

    private

      def process_response response
        if response.status.eql? 422
          response_body = parse(response.body)
          field = "Email ID"
          fields_hash = {"email" => "Email ID", "phone" => "Phone", "twitter" => "Twitter"}
          fields_hash.each do |k,v| 
            field = v if response_body.include? k
          end

          return {:status => 422, :message => I18n.t(:'integrations.fullcontact.message.invalid_contact_fields', :name => field || "required" )}
        end
        super
      end

      def contact_fields_list
        Account.current.contact_form.fields.collect{|field| field["name"]} << "avatar"
      end

      def webhook_params
        {
          "webhookUrl" => "https://#{Account.current.full_domain}/integrations/fullcontact/callback", 
          "webhookId"  => "contact:#{@current_contact.id}" 
        }
      end

      def add_user_avatar image_url
        begin
          if current_contact
            file = RemoteFile.new(image_url).fetch
            if file
              avatar = current_contact.build_avatar({:content => file })
              avatar.account = Account.current
              avatar.save
            end
          end
        ensure
          if file
            file.unlink_open_uri if file.open_uri_path
            file.close
            file.unlink
          end
        end
      end
      
      def current_contact
        @current_contact ||= Account.current.contacts.find(@service.payload[:contact_id])
      end
      
      def contact_response
        @contact_response ||= IntegrationServices::Services::Fullcontact::Formatter::ContactFormatter.new(@service.payload[:result])
      end

    end
  end
end