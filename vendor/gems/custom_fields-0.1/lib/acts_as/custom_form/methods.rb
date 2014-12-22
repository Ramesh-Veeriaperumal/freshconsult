module ActAs
  module CustomForm
    
    module Methods
      
      def to_ff_field ff_alias
        idx = nil
        ffa = "#{ff_alias}"
        ff_aliases.each_with_index do |c,i|
          idx = i if c == ffa
        end
        idx ? custom_fields_cache[idx].to_ff_field : nil
      end

      def to_ff_alias ff_field
        idx = nil
        fff = "#{ff_field}" #make sure it is a string
        ff_fields.each_with_index do |c,i|
          idx = i if c == fff
        end
        idx ? custom_fields_cache[idx].to_ff_alias : nil
      end
      
      def ff_aliases
        custom_fields_cache.nil? ? [] : custom_fields_cache.map(&:name)
      end

      def ff_fields
        custom_fields_cache.nil? ? [] : custom_fields_cache.map(&:column_name)
      end

    end

  end
end