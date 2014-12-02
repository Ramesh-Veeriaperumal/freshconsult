module Inherits
  module CustomField
    
    module Methods

      def to_ff_field ff_alias = nil
        (ff_alias.nil? || name == ff_alias) ? column_name : nil
      end

      def to_ff_alias ff_field = nil
        (ff_field.nil? || column_name == ff_field) ? name : nil
      end

    end

  end
end