# Has FlexibleFields
#
# Copyright (c) 2009 Guy Boertje <gboertje AT gowebtop DOT com>
# see README for license
module Has #:nodoc:
  module FlexibleFields #:nodoc:
  
    def self.included(base) # :nodoc:
      base.extend ClassMethods
    end

    module ClassMethods
      def has_flexiblefields options = {}
        unless includes_flexiblefields?
          
          has_one :flexifield, :as => :flexifield_set, :dependent => :destroy
          delegate :assign_ff_values, :set_ff_value, :get_ff_value, :ff_def=, :ff_def, :to_ff_alias, :ff_aliases, :to_ff_field, :ff_fields, :to => :flexifield
          
          accepts_nested_attributes_for :flexifield
          
          accepts_nested_attributes_for :flexifield_picklist_val
          
          after_create :create_flexifield
          after_save :save_flexifield
          
#          if options[:some_option]
#
#          end

        end

        include InstanceMethods

      end
      
      def includes_flexiblefields?
        self.included_modules.include?(InstanceMethods)
      end

      def create_ff_tables!
        self.connection.create_table :flexifields do |t|
          t.integer :flexifield_def_id
          t.integer :flexifield_set_id
          t.string  :flexifield_set_type
          t.timestamps
          1.upto(30) {|i| t.string "ffs_" + (i < 10 ? "0#{i}" : "#{i}")}
          1.upto(10) {|j| t.string "ff_int" + (j < 10 ? "0#{j}" : "#{j}")}
          1.upto(10) {|k| t.string "ff_date" + (k < 10 ? "0#{k}" : "#{k}")}
          
        end
        
        self.connection.create_table :flexifield_defs do |t|
          t.string      :name, :null => false
          t.integer     :account_id
          t.string      :module
          t.timestamps
        end

        self.connection.create_table :flexifield_def_entries do |t|
          t.integer     :flexifield_def_id, :null => false
          t.string      :flexifield_name, :null => false
          t.string      :flexifield_alias, :null => false
          t.string      :flexifield_tooltip
          t.integer     :flexifield_order
          t.string      :flexifield_coltype
          t.string      :flexifield_defVal
          t.timestamps
        end
        
        self.connection.create_table :flexifield_picklist_vals do |t|
          t.integer     :flexifield_def_entry_id, :null => false
          t.string      :value         
          t.timestamps
        end

        self.connection.add_index :flexifields, [:flexifield_set_id, :flexifield_set_type], :name => 'idx_ff_poly'
        self.connection.add_index :flexifields, :flexifield_def_id

        self.connection.add_index :flexifield_def_entries, [:flexifield_def_id, :flexifield_order], :name => 'idx_ffde_ordering'
        self.connection.add_index :flexifield_def_entries, [:flexifield_def_id, :flexifield_name], :name => 'idx_ffde_onceperdef', :unique => true

        self.connection.add_index :flexifield_defs, [:name, :account_id], :name => 'idx_ffd_onceperdef', :unique => true
        
      end
      
      def drop_ff_tables!
        self.connection.drop_table :flexifield_def_entries
        self.connection.drop_table :flexifield_defs
        self.connection.drop_table :flexifields
        self.connection.drop_table :flexifield_picklist_vals
      end
    end
    
    module InstanceMethods
      def has_ff_def?
        flexifield.nil? ? false : !flexifield.flexifield_def_id.nil?
      end   
      
      protected
      
      def save_flexifield
        self.flexifield.save
      end
      
      def create_flexifield
        self.flexifield = Flexifield.new()
      end
      
    end
  end
end