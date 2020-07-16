class Sync::FileToData::PushToSql
  include Sync::FileToData::Util
  include Sync::Constants
  attr_accessor :retain_id, :resync, :self_associations, :account, :mapping_table, :deleted_associations

  def initialize(root_path, master_account_id, retain_id = false, resync = false, clone = false, account = Account.current)
    @root_path = root_path
    @resync = resync
    @retain_id = retain_id
    @clone = clone
    @master_account_id = master_account_id
    @account = Account.current
    @self_associations = []
    @deleted_associations = {}
    @transformer = Sync::FileToData::Transformer.new(master_account_id, resync, @clone)
    @mapping_table = {
      'Account' => {
        id: {
          master_account_id => account.id
        }
      }
    }
    #@mapping_table = load_mapping_table(root_path.gsub(RESYNC_ROOT_PATH, GIT_ROOT_PATH)).merge!(@mapping_table) if resync
  end

  def perform(model, path, action)
    Sync::Logger.log("Push data to sql Model: #{model} Path:#{path}")
    initialize_mapping_table(model)
    return unless File.directory?(path)
    object              = model.constantize.new
    serialized_columns  = object.class.serialized_attributes.keys
    table_name          = object.class.table_name
    if File.directory?(path)
      item = File.basename(path)
      return if skip_id?(model, item.to_i, action)
      table = Arel::Table.new(table_name.to_sym)
      column_values = {}

      traverse_directory(path) do |file|
        file_path = File.join(path, file)
        column    = file.gsub(FILE_EXTENSION, '')
        next if File.directory?(file_path) || UPDATE_ASSOCIATIONS.include?(column)
        data = YAML.load_file(file_path)
        column_values[column] = data
      end
      if !ignore_soft_deleted_model?(table_name) && object.respond_to?('deleted') && action == :deleted
        action = :modified
        arel_values = [[table[:deleted], 1]]
      else
        arel_values = apply_mapping(column_values, model, table, serialized_columns, action)
      end
      arel_values << [table[:updated_at], Time.now] if object.respond_to?('updated_at')
      arel_values << [table[:account_id], account.id]
      arel_values << [table[:id], generate_id(item, model)] if generate_id?(item, model)
      ret_val = send(action, table_name, item.to_i, arel_values, object, table)
      @mapping_table[model][:id][item.to_i] = ret_val if ret_val.present?
    end
  end

  def apply_mapping(column_values, model, table, serialized_columns, action)
    Sync::Logger.log("Apply Mapping  Model : #{model} Column Values : #{column_values.inspect}")
    ret_val = []
    column_values.each do |column, data|
      association = MODEL_DEPENDENCIES[model].detect { |x| x[1].to_s == column.to_s }
      if association.present?
        associated_model = column_values[association[2]] || association[0].first
        next unless associated_model
        associated_model = 'VaRule' if associated_model == 'VARule'
        if associated_model.to_s == model.to_s
          @self_associations.push([model, column, association[2]])
        else
          Sync::Logger.log("Associated Model : #{associated_model} ** Column : #{column} ** Model : #{model}")
          column_values[column] = @mapping_table[associated_model][:id][data] if data && @mapping_table[associated_model] && @mapping_table[associated_model][:id][data]
        end
      elsif column_values[column].present? && action != :deleted && @transformer.available?(model, column)
        transformed_column_value = @transformer.safe_send("transform_#{model.gsub('::', '').snakecase}_#{column}", column_values[column], @mapping_table)
        Sync::Logger.log("available transformer, column: #{column}, value: #{column_values[column].inspect}, transformed_column_value: #{transformed_column_value.inspect}  model: #{model}")
        if @transformer.can_map_column?(model, column) || (transformed_column_value != column_values[column] && !serialized_columns.include?(column))
          @mapping_table[model][column] ||= {}
          @mapping_table[model][column][column_values[column]] = transformed_column_value
        end
        column_values[column] = transformed_column_value
      end
      column_values[column] = column_values[column].to_yaml if serialized_columns.include?(column)
      ret_val << [table[column.to_sym], column_values[column]]
    end
    ret_val
  end

  private

    def generate_id?(item, model)
      !@clone && !resync && !item.to_i.zero?
    end

    def generate_id(item, model)
      @transformer.apply_id_mapping(item)
    end

    def added(table_name, item_id, arel_values, object, _table = nil)
      return if record_present?(table_name, Account.current.id, item_id, object)
      delete_and_insert(table_name, item_id, arel_values)
    end

    def deleted(table_name, item_id, arel_values, _object, _table = nil)
      model = model_table_mapping.key(table_name)
      if item_id.zero?
        column_names = model.constantize.columns.collect(&:name)
        diff_columns = column_names - arel_values.map{|a| a[0].name.to_s}
        raise("Sandbox HABTM delete record failed. Column missing in table #{table_name} columns #{diff_columns}") if diff_columns.present?
        delete_habtm_record(table_name, arel_values)
      else
        return if Sharding.select_shard_of(@master_account_id) {  Sharding.run_on_slave { record_present?(table_name, @master_account_id, @transformer.calc_id(item_id), model.constantize) } }
        @deleted_associations[model] ||= []
        @deleted_associations[model].append(item_id)
        delete_record(table_name, item_id)
      end
    end

    def ignore_soft_deleted_model?(table_name)
      IGNORE_SOFT_DELETE_TABLES.include?(table_name)
    end

    def modified(_table_name, item_id, arel_values, object, table)
      return if item_id.zero?
      update_manager = Arel::UpdateManager.new table.engine
      update_manager.set(arel_values).where(table[:id].eq(item_id)).table(table)
      ActiveRecord::Base.connection.execute(update_manager.to_sql)
    end

    def initialize_mapping_table(model)
      @mapping_table[model] ||= {}
      @mapping_table[model][:id] ||= {}
    end

    def skip_id?(model, id, action)
      (@mapping_table[model][:id][id].present? && action == :added)
    end
end
