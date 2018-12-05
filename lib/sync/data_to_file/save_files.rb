class Sync::DataToFile::SaveFiles
  include Sync::DataToFile::Util
  attr_accessor :sandbox, :account
  def initialize(sandbox = false, transformer = nil)
    @sandbox = sandbox
    @transformer = transformer
  end

  def dump_object_and_associations(path, base_object, config, associations)
    # @param  path       Base directory  to traverse the items for the base object Ex:(/tmp/sandbox/#{account.id}/ticket_fields)
    # @param base_object Account object
    # @param config One of the config define in relations Ex(Ticket_fields)
    # @param association Associations for the given config

    objects = [*base_object.safe_send(config)]
    objects.each do |object|
      next if ignore_object?(object)
      obj_id = generate_id(object, config)
      dump_object(path, config, object, obj_id)
      associations.each do |association|
        if association.is_a?(Hash)
          association.keys.each do |key|
            if object.safe_send(key).present?
              dump_object_and_associations("#{path}/#{config}/#{obj_id}", object, key, association[key])
            end
          end
        else
          relations = [*association]
          relations.each do |relation|
            relation_objects = [*object.safe_send(relation)]
            relation_objects.each_with_index do |relation_obj, i|
              relation_obj_id = generate_id(relation_obj, relation, i + 1)
              dump_object("#{path}/#{config}/#{obj_id}", relation, relation_obj, relation_obj_id)
            end
          end
        end
      end
    end
  end

  private

    def dump_object(path, association, object, obj_id)
      columns = object.class.columns.collect(&:name) - IGNORE_ASSOCIATIONS
      columns.each do |column|
        file_path = "#{path}/#{association}/#{obj_id}/#{column}#{FILE_EXTENSION}"
        content   = object.read_attribute(column) # using read attribute to read the value in mysql in case method override(custom_form)
        content = apply_mapping(model_name(object), object, column, content)
        create_file(file_path, YAML.dump(content))
      end
    end

    def generate_id(object, association, counter = -1)
      # Need to remove counter logic
      model = model_name(object)
      obj_id = (object.id.nil? && (counter != -1) ? "#{association}_#{merged_ids(object, model)}" : object.id)
      return obj_id unless sandbox
      transform_id(@transformer, obj_id, model)
    end

    def apply_mapping(model, object, column, data)
      association = MODEL_DEPENDENCIES[model].to_a.detect { |x| x[1].to_s == column.to_s }
      if sandbox && @transformer.available_column?(model, column, object)
        Sync::Logger.log('*' * 100 + "  ---- apply_mapping  Model: #{model} column: #{column} data: #{data.inspect} ")
        @transformer.safe_send("transform_#{model.gsub('::', '').snakecase}_#{column}", data)
      elsif sandbox && association.present?
        associated_model = association[2] && object.respond_to?(association[2]) ? 
          object.safe_send(association[2]) : association[0].first
        associated_model = 'VaRule' if associated_model == 'VARule'
        transform_id(@transformer, data, associated_model)
      elsif data.is_a?(Hash) && (SKIP_SYMBOLIZE_KEYS[model] || []).exclude?(column)
        data.symbolize_keys
      elsif data.is_a?(Array)
        data.each { |el| el.symbolize_keys! if el.is_a?(Hash) }
      else
        data
      end
    end

    def ignore_object?(object)
      return true if object.respond_to?('deleted') && object.deleted #soft delete ignore
      Account.current.freshid_enabled? && (agent_policy?(object) || agent_invitation?(object))
    end

    def agent_policy?(object)
      object.class.name == 'PasswordPolicy' && object.user_type == PasswordPolicy::USER_TYPE[:agent]
    end

    def agent_invitation?(object)
      object.class.name == 'EmailNotification' && object.notification_type == EmailNotification::AGENT_INVITATION
    end

    def merged_ids(object, model)
      object.attributes.except!('account_id').values.sort.map { |c_id| sandbox ? transform_id(@transformer, c_id, model) : c_id }.join('_')
    end
end
