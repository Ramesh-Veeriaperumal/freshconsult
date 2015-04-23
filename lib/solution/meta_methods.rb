#This file won't be needed after enabling multi-lingual solutions feature for all accounts
module Solution::MetaMethods

	DEFAULT_ASSIGNS = {
		"Solution::Category" => ['account_id', 'account_id'],
		"Solution::Folder" => ['solution_category_meta_id', 'category_id'],
		"Solution::Article" => ['solution_folder_meta_id', 'folder_id']
	}

	LANGUAGE_MAPPING = (
		I18n.available_locales.inject(HashWithIndifferentAccess.new) { |h,lang| h[lang] = I18n.t('meta', locale: lang); h }
	)

	def self.included(base)
		base.class_eval do 
			after_save :save_meta
		end
	end

	def meta_class
		"#{self.class.name}Meta".constantize
	end

	def meta_association
		meta_class.model_name.singular
	end

	def build_meta
		obj = meta_object(self.attributes.slice(*common_meta_attributes))
		assign_defaults(obj)
	end

	def common_meta_attributes
		meta_class::COMMON_ATTRIBUTES
	end

	def save_meta
		obj = meta_object
		changed_attribs.each do |attrib|
			obj.send("#{attrib}=", self.send(attrib))
		end
		assign_defaults(obj)
		obj.save
	end

	def changed_attribs
		self.new_record? ? common_meta_attributes : (common_meta_attributes & self.changes.keys)
	end

	def new_meta(attributes = {})
		Account.current.send(meta_association).new(attributes)
	end

	def meta_object(attributes = {})
		self.send(meta_association) || new_meta(attributes)
	end

	def assign_defaults obj
		obj.id = self.id
		obj.send("#{assign_keys.first}=", self.send(assign_keys.last))
		obj
	end

	def assign_keys
		DEFAULT_ASSIGNS[self.class.name]
	end

	def language=(value)
		self.language_id = LANGUAGE_MAPPING[value][:language_id]
	end

	def language
		language_code 
	end

	def language_code
		LANGUAGE_MAPPING.key(LANGUAGE_MAPPING.values.select { |x| x[:language_id] == language_id }.first)
	end

	def language_name
		LANGUAGE_MAPPING[language_code][:language_name]
	end	
end