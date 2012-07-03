module ActiveRecord
  
  module AssociationPreload #:nodoc:
    def self.included(base)
      base.extend(ClassMethods)
    end
  
  module ClassMethods
  
  private
   def preload_belongs_to_association(records, reflection, preload_options={})
        return if records.first.send("loaded_#{reflection.name}?")
        options = reflection.options
        primary_key_name = reflection.primary_key_name

        if options[:polymorphic]
          polymorph_type = options[:foreign_type]
          klasses_and_ids = {}

          # Construct a mapping from klass to a list of ids to load and a mapping of those ids back to their parent_records
          records.each do |record|
            if klass = record.send(polymorph_type)
              klass_id = record.send(primary_key_name)
              if klass_id
                id_map = klasses_and_ids[klass] ||= {}
                id_list_for_klass_id = (id_map[klass_id.to_s] ||= [])
                id_list_for_klass_id << record
              end
            end
          end
          klasses_and_ids = klasses_and_ids.to_a
        else
          id_map = {}
          records.each do |record|
            key = record.send(primary_key_name)
            if key
              mapped_records = (id_map[key.to_s] ||= [])
              mapped_records << record
            end
          end
          klasses_and_ids = [[reflection.klass.name, id_map]]
        end

        klasses_and_ids.each do |klass_and_id|
          klass_name, id_map = *klass_and_id
          next if id_map.empty?
          klass = klass_name.constantize

          table_name = klass.quoted_table_name
          primary_key = reflection.options[:primary_key] || klass.primary_key
          column_type = klass.columns.detect{|c| c.name == primary_key}.type
          ids = id_map.keys.map do |id|
            if column_type == :integer
              id.to_i
            elsif column_type == :float
              id.to_f
            else
              id
            end
          end
          conditions = "#{table_name}.#{connection.quote_column_name(primary_key)} #{in_or_equals_for_ids(ids)}"
          conditions << append_conditions(reflection, preload_options)
          find_options = { :conditions => [conditions, ids], :include => options[:include],
                           :select => options[:select], :joins => options[:joins], :order => options[:order] }

          associated_records = klass.send(klass == self ? :with_exclusive_scope : :with_scope, :find => find_options) { klass.all }
          set_association_single_records(id_map, reflection.name, associated_records, primary_key)
        end
      end

      
      def preload_has_and_belongs_to_many_association(records, reflection, preload_options={})
        table_name = reflection.klass.quoted_table_name
        id_to_record_map, ids = construct_id_map(records)
        records.each {|record| record.send(reflection.name).loaded}
        options = reflection.options

        conditions = "t0.#{reflection.primary_key_name} #{in_or_equals_for_ids(ids)}"
        conditions << append_conditions(reflection, preload_options)

        find_options = { :conditions => [conditions, ids], :include => options[:include], :order => options[:order],
                         :joins => "INNER JOIN #{connection.quote_table_name options[:join_table]} t0 ON #{reflection.klass.quoted_table_name}.#{reflection.klass.primary_key} = t0.#{reflection.association_foreign_key}",
                         :select => "#{options[:select] || table_name+'.*'}, t0.#{reflection.primary_key_name} as the_parent_record_id" }
                         

        associated_records = reflection.klass.send(reflection.klass == self ? :with_exclusive_scope : :with_scope, :find => find_options) { reflection.klass.all }
        set_association_collection_records(id_to_record_map, reflection.name, associated_records, 'the_parent_record_id')
    end
    
    def preload_has_one_association(records, reflection, preload_options={})
        return if records.first.send("loaded_#{reflection.name}?")
        id_to_record_map, ids = construct_id_map(records, reflection.options[:primary_key])
        options = reflection.options
        records.each {|record| record.send("set_#{reflection.name}_target", nil)}
        if options[:through]
          through_records = preload_through_records(records, reflection, options[:through])
          through_reflection = reflections[options[:through]]
          through_primary_key = through_reflection.primary_key_name
          unless through_records.empty?
            source = reflection.source_reflection.name
            through_records.first.class.preload_associations(through_records, source)
            if through_reflection.macro == :belongs_to
              rev_id_to_record_map, rev_ids = construct_id_map(records, through_primary_key)
              rev_primary_key = through_reflection.klass.primary_key
              through_records.each do |through_record|
                add_preloaded_record_to_collection(rev_id_to_record_map[through_record[rev_primary_key].to_s],
                                                   reflection.name, through_record.send(source))
              end
            else
              through_records.each do |through_record|
                add_preloaded_record_to_collection(id_to_record_map[through_record[through_primary_key].to_s],
                                                   reflection.name, through_record.send(source))
              end
            end
          end
        else
          set_association_single_records(id_to_record_map, reflection.name, find_associated_records(ids, reflection, preload_options), reflection.primary_key_name)
        end
    end
    
    def preload_has_many_association(records, reflection, preload_options={})
         return if records.first.send(reflection.name).loaded?
        options = reflection.options

        primary_key_name = reflection.through_reflection_primary_key_name
        id_to_record_map, ids = construct_id_map(records, primary_key_name || reflection.options[:primary_key])
        records.each {|record| record.send(reflection.name).loaded}

        if options[:through]
          through_records = preload_through_records(records, reflection, options[:through])
          through_reflection = reflections[options[:through]]
          unless through_records.empty?
            source = reflection.source_reflection.name
            through_records.first.class.preload_associations(through_records, source, options)
            through_records.each do |through_record|
              through_record_id = through_record[reflection.through_reflection_primary_key].to_s
              add_preloaded_records_to_collection(id_to_record_map[through_record_id], reflection.name, through_record.send(source))
            end
          end

        else
          set_association_collection_records(id_to_record_map, reflection.name, find_associated_records(ids, reflection, preload_options),
                                             reflection.primary_key_name)
        end
    end
    
   
    
    def set_association_collection_records(id_to_record_map, reflection_name, associated_records, key)
        associated_records.each do |associated_record|
          mapped_records = id_to_record_map[associated_record[key].to_s]
          add_preloaded_records_to_collection(mapped_records, reflection_name, associated_record)
        end
      end
    
    def find_associated_records(ids, reflection, preload_options)
        options = reflection.options
        table_name = reflection.klass.quoted_table_name
        if interface = reflection.options[:as]
          parent_type = if reflection.active_record.abstract_class?
            self.base_class.sti_name
          else
            reflection.active_record.sti_name
          end

          conditions = "#{reflection.klass.quoted_table_name}.#{connection.quote_column_name "#{interface}_id"} #{in_or_equals_for_ids(ids)} and #{reflection.klass.quoted_table_name}.#{connection.quote_column_name "#{interface}_type"} = '#{parent_type}'"
        else
          foreign_key = reflection.primary_key_name
          conditions = "#{reflection.klass.quoted_table_name}.#{foreign_key} #{in_or_equals_for_ids(ids)}"
        end

        conditions << append_conditions(reflection, preload_options)

        find_options = { :select => (preload_options[:select] || options[:select] || "#{table_name}.*"),
                         :include => preload_options[:include] || options[:include], :conditions => [conditions, ids],
                         :joins => options[:joins], :group => preload_options[:group] || options[:group],
                         :order => preload_options[:order] || options[:order] }
        reflection.klass.send(reflection.klass == self ? :with_exclusive_scope : :with_scope, :find => find_options) { reflection.klass.all }
      end

    
end  
end

  
end


   