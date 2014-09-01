module HasNoTable
  
  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    # generates two methods
    # method columns()
    # returns a array of columns
    # @columns is the instance variable where all the columns information is stored
    
    # method column(name, sql_type = nil, default = nil, null = true)
    # inserts each column into the the instance variable @columns
    # gets the following parameters
    # name - (column name)
    # sql_type - ("integer","text"),
    # default - (default value)
    # null - can be nil or not default is set to true
    
    def has_no_table
      instance_eval %Q(
        def columns() @columns ||= []; end
        def column(name, sql_type = nil, default = nil, null = true)
          columns << ActiveRecord::ConnectionAdapters::Column.new(name.to_s, default, sql_type.to_s, null)
          override_attribute_accessors(name)
        end
      )
    end

    # overides the attribute accessor methods for various columns
    # sets an instance variable to  identify if an attribute is changed or new record
    def override_attribute_accessors(name)
      class_eval %Q(
        def #{name.to_s}=(column_name)
          self.#{name.to_s}_changed = true if(self.#{name.to_s})
          self.write_attribute("#{name.to_sym}",column_name)
        end

        def #{name}_changed?
          self.#{name}_changed ? true : false
        end
      )
    end

  end
end