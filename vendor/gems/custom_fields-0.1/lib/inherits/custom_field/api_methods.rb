module Inherits
  module CustomField
    module ApiMethods

      #including field_type as attribute in to_xml is breaking in rails3. So including as method and excluding from attributes.

      def to_xml(options = {})
        options[:indent] ||= 2
        xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
        xml.instruct! unless options[:skip_instruct]
        super(:builder => xml, :skip_instruct => true, :except => [:account_id, :column_name, self.class::CUSTOM_FORM_ID_COLUMN, :field_type], :methods => [:field_type]) do |xml|
          xml.choices do
            choices.each do |choice|  
              xml.option do
                xml.tag!('name',choice[:name].to_s)
                xml.tag!('value',choice[:value].to_s)
              end
            end
          end
        end
      end
      
      #Use as_json instead of to_json for future support Rails3 refer:(http://jonathanjulian.com/2010/04/rails-to_json-or-as_json/)
      def as_json(options={})
        options[:except] ||= [:account_id, :column_name, self.class::CUSTOM_FORM_ID_COLUMN]
        options[:methods]||= [:choices]
        super(options)
      end
      
    end
  end
end