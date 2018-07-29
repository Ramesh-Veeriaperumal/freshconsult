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
      dump_object(path, config, object)
      associations.each do |association|
        if association.is_a?(Hash)
          association.keys.each do |key|
            if object.safe_send(key).present?
              dump_object_and_associations("#{path}/#{config}/#{object.id}", object, key, association[key])
            end
          end
        else
          relations = [*association]
          relations.each do |relation|
            relation_objects = [*object.safe_send(relation)]
            relation_objects.each_with_index do |relation_obj, i|
              dump_object("#{path}/#{config}/#{object.id}", relation, relation_obj, i + 1)
            end
          end
        end
      end
    end
  end

  private

    def dump_object(path, association, object, counter = -1)
      columns = object.class.columns.collect(&:name) - IGNORE_ASSOCIATIONS
      obj_id = generate_id(object, association, counter)
      columns.each do |column|
        file_path = "#{path}/#{association}/#{obj_id}/#{column}#{FILE_EXTENSION}"
        content   = object.read_attribute(column) # using read attribute to read the value in mysql in case method override(custom_form)
        content = apply_mapping(model_name(object), object, column, content)
        create_file(file_path, YAML.dump(content))
      end
    end

    def generate_id(object, association, counter)
      # Need to remove counter logic
      obj_id = (object.id.nil? && (counter != -1) ? "#{association}_#{object.attributes.except!("account_id").values.sort.join("_")}" : object.id)
      return obj_id unless sandbox
      transfrom_id(@transformer, obj_id, model_name(object))
    end

    def apply_mapping(model, object, column, data)
      if sandbox && @transformer.available_column?(model, column)
        sync_logger.info('*' * 100 + "  ---- apply_mapping  Model: #{model} column: #{column} data: #{data} ")
        data = @transformer.safe_send("transform_#{model.gsub('::', '').snakecase}_#{column}", data)
      elsif sandbox && model == 'Helpdesk::Attachment' && column == 'attachable_id'
        data = @transformer.transfor_helpdesk_attachment_attachable_id(data, object)
      end
      data
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
end
