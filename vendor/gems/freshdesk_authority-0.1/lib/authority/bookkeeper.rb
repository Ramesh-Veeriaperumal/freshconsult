module Authority
  class Bookkeeper
      
    def initialize(file)
      @file = file
    end
    
    # 1. If file does not exist, then covert the privileges to hash 
    #    e.g {:manage_account => 2, :view_forums => 12}
    #    and write to file
    # 2. Else read data from file and get :max_value
    # 3. get the keys(privilege names) 
    # 4. get added data and add them to hash
    # 5. write the new data
  
    def map(privileges)
      # 1
      @data = {}
      unless File.exist?("#{RAILS_ROOT}/config/#{@file}")
        @data[:privileges] = build_data(privileges)
        @data[:max_value] = @data[:privileges].values.max
      else
        # 2
        @data = read_file
        @max_index = @data[:max_value]
        # 3
        keys = @data[:privileges].keys
        # 4 
        added = privileges - keys
        add_data(added)
      end
      # 5      
      write_file
    end

    def purge
      @data = read_file
      deleted = @data[:privileges].keys - Authority::Authorization::PrivilegeList.privileges_by_name
      delete_data(deleted)
      write_file
    end

    def load_privileges
      read_file[:privileges]
    end

    private

      def write_file
        File.open("#{RAILS_ROOT}/config/#{@file}", "w") do |f|
          f.write(@data.to_yaml)
        end  
      end

      def read_file
        YAML.load_file("#{RAILS_ROOT}/config/#{@file}")
      end

      def build_data(data)
        data.inject({}) do  |hash, value|
          hash[value] = data.index(value) 
          hash
        end
      end

      def delete_data(deleted)
        deleted.each {|value| @data[:privileges].delete(value)}
      end

      def add_data(added)        
        added.each { |value| @data[:privileges][value] = next_index }
        @data[:max_value] = @max_index
      end

      def next_index
        @max_index += 1
      end

  end
end