module AuditLog::AuditLogHelper
  private

    # options can have the likes of type (ex. :default, :currency), and any other custom value
    def description_properties(*params)
      key, value, options = params
      options ||= {}
      options.symbolize_keys!
      modified_value = value.present? ? default_value(value) : nil
      modified_value = value if options[:type] == :array
      { type: :default, field: key, value: modified_value }.merge!(options)
    end

    def nested_data(nested_value, options)
      nested_value.map do |each_value|
        each_value.symbolize_keys!
        description_properties(each_value[:value] || '', each_value[:name],
                               options.merge(id: each_value[:id]))
      end
    end

    def nested_description(*params)
      key, value, model_name, options = params
      options ||= {}
      changed_value = []
      value.each_pair do |nested_key, nested_value|
        changed_value << description_properties(translated_key(nested_key, model_name),
                                                nested_data(nested_value, options), type: :array)
      end
      description_properties(key, changed_value, type: :array)
    end

    def translated_key(key, model_name)
      I18n.t("#{AuditLogConstants::MODEL_TRANSLATION_PATH[model_name]}#{key}")
    end

    def translated_value(constant_name, value)
      constant_object = begin
                          AuditLogConstants.const_get(constant_name)
                        rescue StandardError
                          nil
                        end
      if constant_object.present?
        return [I18n.t(constant_object[value[0]]), I18n.t(constant_object[value[1]])]
      end
      value
    end

    def default_value(value)
      if value.present?
        value.is_a?(Array) ? { from: value[0], to: value[1] } : value
      end
    end

    def activity_description(model_name, response)
      model_data = response[:object]
      changes = response[:changes]
      if changes.present?
        changes_dup = changes.dup
        changes_dup.delete :updated_at
        safe_send("#{model_name}_changes", model_data, changes_dup)
      else
        description_properties(model_data[:name], nil)
      end
    end

    def performer(activity)
      agent = activity[:actor]
      {
        id: agent[:id],
        name: agent[:name],
        url_type: 'agent'
      }
    end

    def event_type_and_description(activity, action, event_type)
      event_type = event_type.join('_')
      response = {
        action: action,
        event_type: translated_key(event_type, :event_type)
      }
      if action == :update
        response[:description] = activity_description(event_type,
                                                      activity)
      end
      response
    end

    def meta_data(response)
      meta = {}
      links = response[:links]
      if links.present?
        meta_data = links[0].symbolize_keys!
        meta[:next] = meta_data[:href]
      end
      meta
    end

    def event_name_route(name, type, object)
      user_id = object[:user_id]
      id = object[:id]
      type = type.join('_')
      name ||= type
      {
        name: name, url_type: type, id: (type.to_sym == :agent ? user_id : id)
      }
    end

    def enrich_response(response)
      response.symbolize_keys!
      enriched_data = {
        data: response[:data].map do |activity|
          activity = deep_symbolize_keys(activity)
          *event_type, action = activity[:action].split('_')
          action = action.to_sym
          custom_response = {
            time: activity[:timestamp],
            ip_address: activity[:ip_address] ? activity[:ip_address].gsub('.', '. ') : nil,
            name: event_name_route(activity[:object][:name], event_type, activity[:object]),
            event_performer: performer(activity)
          }
          custom_response.merge! event_type_and_description(activity, action, event_type)
          custom_response
        end
      }
      enriched_data.merge! meta_data(response)
    end

    # custom function to deep symbolize keys because of different ruby version on production and local
    # Note: feel free to delete it when there is no issue
    # For developers looking for def deep_symbolize_keys!, include hashr in your Gemfile. It's not added for development.
    def deep_symbolize_keys(changes)
      symbolize = lambda do |value|
        case value
        when Hash
          deep_symbolize_keys(value)
        when Array
          value.map { |value| symbolize.call(value) }
        else
          value
        end
      end
      changes.inject({}) do |result, (key, value)|
        result[(key.to_sym rescue key) || key] = symbolize.call(value)
        result
      end
    end
end
