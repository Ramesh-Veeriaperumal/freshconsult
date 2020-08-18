module CentralPublish::CRECentralUtil
  CRE_PAYLOAD_TYPES = {
    webhook_error: 'webhook_error'
  }.freeze

  def construct_webhook_error_payload(args)
    executing_rule = VaRule.find_by_id(args[:rule_id])
    payload = default_schema_cre(CRE_PAYLOAD_TYPES[:webhook_error], args[:account_id])
    payload[:payload][:data] = {
      error_type: args[:error_type],
      rule_type: executing_rule.present? ? executing_rule.rule_type_desc.to_s : nil,
      reset_metric: args.key?(:reset_metric) ? args[:reset_metric] : nil,
      rule_id: args[:rule_id]
    }
    payload[:payload][:context] = {
      ticket_id: args[:ticket_id]
    }
    payload
  end

  def default_schema_cre(payload_type, account_id)
    {
      payload_type: payload_type,
      account_id: account_id.to_s,
      pod: PodConfig['CURRENT_POD'],
      region: PodConfig['CURRENT_REGION'],
      payload: {
        event_info: {
          pod: ChannelFrameworkConfig['pod']
        }
      }
    }
  end

  def generate_msg_id(payload)
    Digest::MD5.hexdigest(payload.to_s)
  end
end
