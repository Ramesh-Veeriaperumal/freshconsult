module Sync
  class FileToConfig
    include SqlUtil
    include Sync::Constants

    attr_accessor :root_path, :master_account_id, :account, :model_directories, :mapping_table, :model_dependencies, :model_insert_order, :self_associations, :retain_id

    def initialize(root_path, master_account_id, retain_id, account=Account.current)
      # raise IncorrectConfigError unless Account.current.respond_to?(config)

      @account         = account
      @root_path       = root_path
      @master_account_id = master_account_id
      @retain_id = retain_id
      @self_associations = []
      @sorter = Sync::TopologicalSorter.new
      @transformer = Sync::Transformer.new(@master_account_id)
      populate_directories_for_models
      build_dependency_list
      find_model_insert_order
      model_table_mapping
      @mapping_table = {
        "Account" => {
          :id => {
            master_account_id.to_s => account.id.to_s
          }
        }
      }
    end

    def update_all_config
      @model_insert_order.each do |model|
        @model_directories[model].each do |model_directory|
          push_data_to_sql(model, model_directory)
        end
        obj = model.constantize.new
        #Clearing cache
        clear_cache_methods = MODEL_MEMCACHE_KEYS[model] || ["clear_cache"]
        clear_cache_methods.each do |clear_cache_method|
          if obj.respond_to?(clear_cache_method, true)
            p "Clearing Cache for : #{model}"
            obj.account_id = Account.current.id if obj.respond_to?("account_id")
            obj.safe_send(clear_cache_method)
          end
        end
      end
      post_data_migration_activities
      #push mapping table
      persist_mapping_table
    end

    def persist_mapping_table
      path = "#{root_path}/mapping_table#{FILE_EXTENSION}"
      content = YAML.dump(mapping_table)
      File.open(path, "w"){ |f| f.puts content}
    end

    def affected_tables
      @model_insert_order.map {|table| @model_table_mapping[table]}.compact
    end

    private

    def populate_directories_for_models
      @model_directories = {}
      RELATIONS.each do |relation|
        @model_directories[relation] = directories_for_model(root_path, account, relation[0])
      end
      consolidate_model_directories
    end

    def directories_for_model(path, base_object, association)
      dir_path = "#{path}/#{association}"
      # p "Dir path : #{dir_path}"
      return {} unless File.directory?(dir_path)
      table_directory = {}
      object   = base_object.class.reflections[association.to_sym].klass.new  #safe_send(association).new
      # p "Object Class : #{object.class} Dir name : #{dir_path}"
      model_name = object.class.superclass.to_s != "ActiveRecord::Base" ? object.class.superclass.to_s : object.class.name
      table_directory[model_name] ||= []
      table_directory[model_name] << dir_path

      Dir.foreach(dir_path) do |item|
        next if item == '.' or item == '..'
       #loop through individual rows
       #TODO: We could add the object path to table_directory to avoid an extra loop when doing update_all_config
       #      but , this might bloat the object.
        object_path = "#{dir_path}/#{item}"
        if File.directory?(object_path)

          Dir.foreach(object_path) do |file|
            next if file == '.' or file == '..'

            file_path = "#{object_path}/#{file}"

            #Recursion
            if File.directory?(file_path)
              # p "Recursion : #{object_path} File : #{file}"
              table_directory.merge!(directories_for_model("#{object_path}", object, file)) {|key, this_val, other_val| [*this_val ,other_val].flatten.uniq }
              next
            end
          end
        end
      end
      table_directory
    end

    def consolidate_model_directories
      @model_directories = {}.tap{ |r| @model_directories.values.each{ |h| h.each{ |k,v| r[k] = [r[k],v].compact.flatten } } }
    end

    def build_dependency_list
      @model_dependencies = MODEL_DEPENDENCIES
    end

    def find_model_insert_order
      @model_insert_order = MODEL_INSERT_ORDER
    end

    def push_data_to_sql(model, path)
      Rails.logger.info "Push data to sql Model: #{model} Path:#{path} "
      @mapping_table[model] ||= {}
      @mapping_table[model][:id] ||= {}
      return unless File.directory?(path)
      object              = model.constantize.new  #safe_send(association).new
      serialized_columns  = object.class.serialized_attributes.keys
      table_name          = object.class.table_name

      Dir.foreach(path) do |item|
        next if item == '.' or item == '..'

        #loop through individual rows

        object_path = "#{path}/#{item}"
        if File.directory?(object_path)
          original_id = item.to_i
          #Skip if already inserted
          next if @mapping_table[model][:id][original_id].present?
          table   = Arel::Table.new(table_name.to_sym)
          column_values = {}

          Dir.foreach(object_path) do |file|
            next if file == '.' or file == '..'

            file_path = "#{object_path}/#{file}"
            next if File.directory?(file_path)
            column    = file.gsub(FILE_EXTENSION,"")

            next if UPDATE_ASSOCIATIONS.include?(column)
            data = YAML::load_file(file_path)
            column_values[column] = data
            # arel_values << [table[column.to_sym], apply_mapping(data, column,  model, serialized_column)]
          end
          
          arel_values = apply_mapping(column_values, model, table, serialized_columns)
          arel_values << [table[:updated_at], Time.now] if object.respond_to?("updated_at")
          arel_values << [table[:account_id], account.id]
          arel_values << [table[:id], item.to_i] if retain_id?(item, model)
          ret_val = delete_and_insert(table_name, item.to_i, arel_values)
          @mapping_table[model][:id][item.to_i] = ret_val if ret_val.present?
        end
      end
    end

    def retain_id?(item, model)
      retain_id && !item.to_i.zero? && ['Helpdesk::Attachment'].exclude?(model) # Add into the list if not to retain_id
    end

    def apply_mapping(column_values, model, table, serialized_columns)
      Rails.logger.info "Apply Mapping  Model : #{model} Column Values : #{column_values.inspect} Mapping Table : #{@mapping_table.inspect}}"
      ret_val = []
      column_values.each do |column, data|
        association = @model_dependencies[model].detect {|x| x[1].to_s == column.to_s}
        if association.present?
          associated_model = column_values[association[2]] || association[0].first
          next unless associated_model
          associated_model = 'VaRule' if associated_model == 'VARule'
          if associated_model.to_s == model.to_s
            @self_associations.push([model, column, association[2]])
          else
            Rails.logger.info "Associated Model : #{associated_model} ** Column : #{column} ** Model : #{model}"
            column_values[column] = @mapping_table[associated_model][:id][data] if data
          end
        elsif column_values[column].present? && @transformer.available?(model, column)
          transformed_column_value = @transformer.safe_send("transform_#{model.gsub("::","").snakecase}_#{column}", column_values[column], @mapping_table)
          if transformed_column_value != column_values[column] && !serialized_columns.include?(column)
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

    def model_table_mapping
      @model_table_mapping ||= Hash[ActiveRecord::Base.safe_send(:descendants).collect{|c| [c.name, c.table_name]}]
    end

    def post_data_migration_activities
      POST_MIGRATION_ACTIVITIES.each do |model, activity|
        activity.call(@master_account_id, @mapping_table[model][:id]) if @mapping_table[model].present?
      end
      clear_account_cache
      #Handling self references!!
      #TODO: Need to handle if the table has multiple self reference columns
      # Which would enable one query per table rather thn association
      @self_associations.uniq.each do |self_association|
        condition = "#{self_association[1]} in (?)"
        condition +=" AND #{self_association[2]} = '#{self_association[0]}'" if self_association[2].present?
        self_association[0].constantize.where([condition, @mapping_table[self_association[0]][:id].keys]).find_in_batches do |collection|
          collection.each do |obj|
            new_value = @mapping_table[self_association[0]][:id][obj.safe_send("#{self_association[1]}")]
            obj.safe_send("#{self_association[1]}=", new_value)
            obj.save
          end
        end
      end
      sync_launch_party_features
      disable_private_inline
    end


    def clear_account_cache
      ACCOUNT_MEMCACHE_KEYS.each do |clear_cache_method|
        Account.current.safe_send(clear_cache_method) if Account.current.respond_to?(clear_cache_method)
      end
    end

    def sync_launch_party_features
      # Need to revisit.
      $redis_others.del("launchparty:#{account.id}:features")
      $redis_others.sadd("launchparty:#{account.id}:features", $redis_others.smembers("launchparty:#{master_account_id}:features"))
    end

    # disable private inline feature for attachments
    def disable_private_inline
      account.revoke_feature(:private_inline) if account.private_inline_enabled?
    end

    ######### Unused functions. Will be used in phase2 ######### 

    def update_config(files)
      table_hash = @affected_tables
      files = files.map{|f| "#{root_path}/#{f}"}
      files.each do |file|
        association     = File.basename(File.dirname(File.dirname(file)))
        table_name      = table_hash[association]
        next if table_name.nil?

        column          = File.basename(file).gsub(FILE_EXTENSION,"")
        item_id         = File.basename(File.dirname(file)).to_i
        value           = cast_value(table_name, column, file)

        table           = Arel::Table.new(table_name.to_sym)
        update_manager  = Arel::UpdateManager.new table.engine
        update_manager.set([[table[column.to_sym], value]]).where(table[:id].eq(item_id)).table(table)
        ActiveRecord::Base.connection.execute(update_manager.to_sql)
      end
    end

    def create_config(files)
    end

    def delete_config(files)
      table_hash = @affected_tables
      deleted_records = {}
      files = files.map{|f| "#{root_path}/#{f}"}

      files.each do |file|
        association     = File.basename(File.dirname(File.dirname(file)))
        table_name      = table_hash[association]

        next if table_name.nil?

        column          = File.basename(file).gsub(FILE_EXTENSION,"")
        item_id         = File.basename(File.dirname(file))

        deleted_records[table_name] ||= []
        deleted_records[table_name] << item_id unless deleted_records[table_name].include?(item_id)
      end

      deleted_records.each do |table, ids|
        next if table.nil?
        ids.each do |id|
          delete_record(table, id)
        end
      end
    end

    def cast_value(table, column, file_path)
      klass               = @model_table_mapping.key(table)
      serialized_columns  = klass.constantize.serialized_attributes.keys
      data = if serialized_columns.include?(column)
        File.read(file_path)
      else
        YAML::load_file(file_path)
      end
    end    
  end
end
