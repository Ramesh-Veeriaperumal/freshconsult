class Solution::Article < ActiveRecord::Base

	has_one :article_body, :autosave => true, :dependent => :destroy

	BODY_ATTRIBUTES = [ "description", "desc_un_html" ]

	alias :original_article_body :article_body

	def article_body
		original_article_body || build_article_body(:account_id => Account.current.id)
	end

	BODY_ATTRIBUTES.each do |attrib|
		define_method "#{attrib}=" do |value|
			article_body.send("#{attrib}=", value)
			write_attribute(attrib, article_body.send("#{attrib}"))
		end

		define_method attrib do
			article_body.send(attrib) || read_attribute(attrib)
		end
	end

	def []=(attr_name, value)
		if(BODY_ATTRIBUTES.include?(attr_name.to_s))
			send("#{attr_name}=", value)
		else
			super(attr_name, value)
		end
	end

	def [](attr_name)
		if(BODY_ATTRIBUTES.include?(attr_name.to_s))
			send("#{attr_name}")
		else
			super(attr_name)
		end
	end
end