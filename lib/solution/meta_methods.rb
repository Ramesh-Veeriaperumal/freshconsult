#This file won't be needed after enabling multi-lingual solutions feature for all accounts
module Solution::MetaMethods

	DEFAULT_ASSIGNS = {
		"Solution::Category" => ['account_id', 'account_id'],
		"Solution::Folder" => ['solution_category_meta_id', 'category_id'],
		"Solution::Article" => ['solution_folder_meta_id', 'folder_id']
	}

	def self.included(base)
		base.class_eval do 
			after_save :save_meta
			before_destroy :destroy_meta
			after_destroy :decrement_positions_on_lower_meta_items
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
		changed_attribs(obj).each do |attrib|
			obj.send("#{attrib}=", self.read_attribute(attrib))
		end
		assign_defaults(obj)
		obj.save
	end

	def destroy_meta
		obj = meta_object
		return if obj.new_record?
		obj.destroy
	end

	def changed_attribs(meta_obj = nil)
		return common_meta_attributes if (self.new_record? || (meta_obj && meta_obj.new_record?))
		common_meta_attributes & self.changes.keys
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

	def decrement_positions_on_lower_meta_items
		scope_condition = meta_class.send(:sanitize_sql_hash_for_conditions, 
				{ assign_keys.first => self.send(assign_keys.last)})
		meta_class.update_all(
			"#{position_column} = (#{position_column} - 1)", 
			"#{scope_condition} AND position > #{send(:position).to_i}"
		)
	end
end