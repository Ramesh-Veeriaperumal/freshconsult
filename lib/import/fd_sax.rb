class Import::FdSax
   include ::SAXMachine
    
    def to_hash
      {}.tap do |hash|
        self.class.column_names.each do |key|
          hash[key] = safe_send(key)
        end
      end
    end  
  
end
