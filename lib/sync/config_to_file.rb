module Sync
  class ConfigToFile
    include SqlUtil        

    attr_accessor :root_path, :base_config, :associations, :account

    def initialize(root_path, config, associations=[], account=Account.current)
      raise IncorrectConfigError unless account.respond_to?(config)

      @account      = account
      @root_path    = root_path
      @base_config  = config
      @associations = associations
    end

    def write_config
      #delete config(files) which have been deleted since last sync
      prune_deleted_rows(root_path, account, base_config) #commenting it out for now.
      dump_object_and_associations(root_path, account, base_config, associations)      
    end
    
    def dump_object(path, association, object, counter=-1)
      columns = object.class.columns.collect(&:name) - IGNORE_ASSOCIATIONS
      obj_id  = ((object.id.nil? and counter != -1) ? "#{association}_#{counter}" : object.id)
      
      columns.each do |column|        
        file_path = "#{path}/#{association}/#{obj_id}/#{column}#{FILE_EXTENSION}"
        content   = YAML.dump(object.read_attribute(column)) #using read attribute to read the value in mysql in case method override(custom_form)
        create_file(file_path, content)
      end
    end    

    private

    def dump_object_and_associations(path, base_object, config, associations)
      #puts "#{path} #{base_object.class} #{base_object.id} #{config} #{associations}"
      
      objects = [*base_object.safe_send(config)]
      objects.each do |object|
        dump_object(path, config, object)
        associations.each do |association|
          if association.is_a?(Hash)
            #recursion
            association.keys.each do |key|
              if !object.safe_send(key).blank?
                dump_object_and_associations("#{path}/#{config}/#{object.id}", object, key, association[key])
              end
            end
          else
            relations = [*association]
            relations.each do |relation|
              relation_objects = [*object.safe_send(relation)]
              relation_objects.each_with_index do |relation_obj, i|
                dump_object("#{path}/#{config}/#{object.id}", relation, relation_obj, i+1)
              end
            end
          end
        end
      end
    end

    def prune_deleted_rows(path, base_object, association)
      dir_path = "#{path}/#{association}"
      
      return unless File.directory?(dir_path)

      Dir.foreach(dir_path) do |item|
        next if item == '.' or item == '..'
        
        #loop through individual rows
        object              = base_object.class.reflections[association.to_sym].klass.new  #safe_send(association).new
        serialized_columns  = object.class.serialized_attributes.keys
        table_name          = object.class.table_name

        object_path = "#{dir_path}/#{item}"
        if File.directory?(object_path)
          Dir.foreach(object_path) do |file|
            next if file == '.' or file == '..'

            file_path = "#{object_path}/#{file}"

            #Recursion
            if File.directory?(file_path)
              prune_deleted_rows("#{object_path}", object, file)
              next
            end
          end
          #Always pruning habtm associations
          if (!item.gsub(/.*_([^_]+)$/, '\1').to_i.zero? && item.to_i.zero?) || (!item.to_i.zero? and !record_present?(table_name,  account.id , item.to_i  ))
            Rails.logger.debug "*"*100+"  ---- Deleting #{table_name} #{item} #{object_path}"
            FileUtils.rm_r(object_path)
            #delete_record(table_name,  item.to_i)
          end
        end
      end  
    end
    
    #create directory if not present
    def create_file(path, content)
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, "w"){ |f| f.puts content}
    end

    class IncorrectConfigError < StandardError
    end
  end
end
