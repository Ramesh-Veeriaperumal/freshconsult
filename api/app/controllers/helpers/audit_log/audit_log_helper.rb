module AuditLog::AuditLogHelper
  include Admin::Automation::CustomStatusHelper
  require 'erb'

  private

    def sanitize_audit_log_value(value)
      value.is_a?(String) ? Helpdesk::HTMLSanitizer.clean(value) : value
    end
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

    def event_name_route(name, type, object, from_export = false)
      user_id = object[:user_id]
      id = object[:id]
      type = type.join('_').camelize(:lower)
      export_url_type = AuditLogConstants::EXPORT_TYPE_CONST
      export_url_type = export_url_type.merge(AuditLogConstants::AUTOMATION_EXPORT_TYPE)
      type = export_url_type[type.to_sym] || type if from_export
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
          event_name = AuditLogConstants::EVENT_TYPES_NAME[event_type.join('_')] || :name
          custom_response = {
            time: activity[:timestamp],
            ip_address: activity[:ip_address] ? activity[:ip_address].gsub('.', '. ') : nil,
            name: event_name_route(activity[:object][event_name], event_type, activity[:object]),
            event_performer: performer(activity)
          }
          custom_response[:name][:folder_id] = activity[:object][:folder_id] if event_type.join('_') == 'canned_response'
          assign_solution_attributes(custom_response, activity) if solution_event?(event_type)
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
      changes.each_with_object({}) do |(key, value), result|
        result[(begin
                  key.to_sym
                rescue StandardError
                  key
                end) || key] = symbolize.call(value)
      end
    end

    def format_file_data(report_data, file_path, file_format)
      value_arr = []
      if report_data
        report_data.each_pair do |key, value|
          case true
          when AuditLogConstants::EXPORT_ENRICHED_KEYS.include?(key)
            value = value == :destroy ? 'delete' : value.to_s
            value_arr.push(value)
          when key == :name
            name = value[:name].to_s
            type = value[:url_type].to_s
            value_arr.push("#{name}\n#{type}")
          when key == :description
            description_arr = []
            description_arr = format_description_array(description_arr, value)
            description_arr = description_arr.join('')
            value_arr.push(description_arr)
          end
        end
        safe_send("write_#{file_format}_data", sanitize_data(value_arr), file_path)
        value_arr.clear
      end
    end

    def write_csv_data(value_arr, file_path)
      CSV.open(file_path, 'ab') do |csv|
        csv << value_arr
      end
    end

    def write_xls_data(value_arr, file_path)
      write_xls(file_path, xls_erb('data'), value_arr)
    end

    def write_xls(file_path, erb, record = [])
      @record = record
      File.open(file_path, 'ab') do |file|
        file.write(erb.result(binding))
      end
    end

    def xls_erb(file_name)
      erb_file_path = format(AuditLogConstants::ERB_PATH, file_name: file_name)
      ERB.new(File.read(erb_file_path))
    end

    def sanitize_data(value_arr)
      # To avoid formula execution in Excel - Removing any preceding =,+,- in any field
      value_arr.map { |value| value && value.is_a?(String) ? value.to_s.gsub(/^[@=+-]*/, '') : value }
    end

    def format_description_array(description_arr, value)
      value.each do |description|
        next if (description[:field]).nil?
        description[:field] = description[:field] == 'Performer' ? 'Action Performed By' : description[:field]
        case true
        when description[:type] == :array
          description[:value].each do |changes|
            description_arr = description_array_extract(description_arr, changes, description)
          end
        when description[:type] == :default
          if description[:value].present?
            value_from = description[:value][:from].presence || '--'
            value_to = description[:value][:to].presence || '--'
            description_arr.push("#{description[:field]}\nfrom:\n#{value_from}\nto:\n#{value_to}\n")
          else
            description_arr.push("#{description[:field]}\n")
          end
        end
      end
      description_arr
    end

    def description_array_extract(description_arr, changes, description)
      description_arr.push("#{description[:field]}: #{changes[:field]}\n")
      changes[:value].each do |ch|
        description_arr.push("\t#{ch[:field]}\n") if ch[:value].nil?
        description_arr.push("\t#{ch[:field]} #{ch[:operator]} #{ch[:value]}\n") if ch[:field] && ch[:operator] && !ch[:value].nil?
        description_arr.push("\t#{ch[:field]} #{ch[:value]}\n") if ch[:field] && !ch[:value].nil? && ch[:operator].nil?
      end
      description_arr
    end

    def solution_event?(event_type)
      AuditLogConstants::SOLUTIONS_EVENT_ITEMS.include?(event_type.join('_'))
    end

    def reset_ratings_pattern?(activity)
      activity[:action] == 'article_update' && (AuditLogConstants::RESET_RATING_FIELDS - activity[:changes].keys).blank?
    end

    def assign_item_attributes(object, response)
      article = Account.current.solution_articles.find(object[:article_id])
      response[:name] = article.title
      response[:language_code] = Language.find(article.language_id).code
    rescue ActiveRecord::RecordNotFound
      response[:name] = I18n.t('admin.audit_log.solution_article.deleted')
    end

    def assign_solution_attributes(response, activity)
      response[:name][:language_code] = activity[:object][:language_code]
      assign_item_attributes(activity[:object], response[:name]) if reset_ratings_pattern?(activity)
    end
end
