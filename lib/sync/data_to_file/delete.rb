class Sync::DataToFile::Delete
  include Sync::DataToFile::Util
  attr_accessor :sandbox, :account, :transformer

  def initialize(sandbox = false, transformer = nil, account = Account.current)
    @sandbox = sandbox
    @account = account
    @transformer = transformer
  end

  def prune_deleted_rows(path, base_object, association)
    # @param  path       Base directory  to traverse the items for the base object Ex:(/tmp/sandbox/#{account.id}/ticket_fields)
    # @param base_object Account object
    # @param association One of the config define in relations Ex(Ticket_fields)

    dir_path = File.join(path, association)
    return unless File.directory?(dir_path)

    traverse_directory(dir_path) do |item|
      # loop through individual rows
      object      = object_from_association(base_object, association)
      object_path = File.join(dir_path, item)

      if File.directory?(object_path)
        traverse_directory(object_path) do |file|
          file_path = "#{object_path}/#{file}"
          if File.directory?(file_path)
            prune_deleted_rows(object_path.to_s, object, file)
            next
          end
        end
        item = transform_id(@transformer, item, model_name(object), true)
        delete_file(object_path) if delete?(item, table_name(object), object)
      end
    end
  end

  private

    def object_from_association(object, association)
      object.class.reflections[association.to_sym].klass.new
    end

    def table_name(object)
      object.class.table_name
    end

    def delete?(item, table_name, object)
      (!item.gsub(/.*_([^_]+)$/, '\1').to_i.zero? && item.to_i.zero?) || (!item.to_i.zero? && !record_present?(table_name, account.id, item.to_i, object))
    end

    def delete_file(path)
      FileUtils.rm_r(path)
    end
end
