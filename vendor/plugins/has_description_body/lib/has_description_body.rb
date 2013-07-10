module HasDescriptionBody

	def self.included(base) 
    base.extend ClassMethods
  end

  module ClassMethods

  	def has_description_body(options = {})
  		model_name = name.demodulize.downcase
      model_body = "#{model_name}_body"
  		# class_def = Class.new(ActiveRecord::Base) do  
  		eval %(

  		class #{name}Body < ActiveRecord::Base
     		set_table_name '#{options[:table_name]}'
     		
     		belongs_to_account
     		belongs_to '#{model_name}'.to_sym, :class_name => #{name}, :foreign_key => '#{model_name}_id'
     		
     		unhtml_it :description
				xss_sanitize :only => [:description_html],  :html_sanitize => [:description_html]

				attr_protected :account_id
			end
			has_one '#{model_body}'.to_sym, :class_name => '#{name}Body', :dependent => :destroy
      accepts_nested_attributes_for '#{model_body}'.to_sym

      class_eval <<-EOV
        def description
          description
        end

        def description_html
          description_html
        end

        def description_with_#{model_body}
          #{model_body}.description
        end
        alias_method_chain :description, '#{model_body}'.to_sym

        def description_html_with_#{model_body}
          #{model_body}.description_html
        end
        alias_method_chain :description_html, '#{model_body}'.to_sym

      EOV
      );
  	end
  end
end