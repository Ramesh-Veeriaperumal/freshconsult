module Proactive
  class SimpleOutreachUpdate < ProactiveServiceCall
    include ::Proactive::Constants

    def initialize(contact_ids, rule_id)
      @contact_ids = contact_ids
      @rule_id = rule_id
      @route = "#{::Proactive::Constants::PROACTIVE_SERVICE_ROUTES[:simple_outreaches_route]}/#{@rule_id}"
    end

    def custom_args
      {
        'route': @route,
        'request_method': 'put',
        'data': build_proactive_service_payload
      }
    end

    def build_proactive_service_payload
      if @contact_ids.blank?
        {
          'user_ids': @contact_ids,
          'status': STATUS[:FAILED]
        }
      else
        {
          'user_ids': @contact_ids
        }
      end
    end
  end
end
