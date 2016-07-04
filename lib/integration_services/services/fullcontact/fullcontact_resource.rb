module IntegrationServices::Services
  module Fullcontact
    class FullcontactResource < IntegrationServices::GenericResource
      include Integrations::Fullcontact::Constants

      def process_response response
        case response.status
        when 200
          {:status => 200, :message => parse(response.body)}
        when 202
          {:status => 202, :message => I18n.t(:'integrations.fullcontact.message.queued')}
        when 400
          {:status => 400, :message => I18n.t(:'integrations.fullcontact.message.invalid_request')}
        when 403
          {:status => 403, :message => I18n.t(:'integrations.fullcontact.message.invalid_api')}
        when 404
          {:status => 404, :message => I18n.t(:'integrations.fullcontact.message.no_results')}
        else
          {:status => 500, :message => I18n.t(:'integrations.fullcontact.message.temp_issue')}
        end
      end
      
      def column_label type, name
        label = nil
        send("#{type}_object").each do |field|
          label = field["label"] and break if field["name"].eql? name
        end
        label
      end

      private

        def contact_object
          @contact_object ||= Account.current.contact_form.fields
        end

        def company_object
          @company_object ||= Account.current.company_form.fields
        end
    end
  end
end
