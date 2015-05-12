module Solution::MetaControllerMethods

	META_ATTRIBUTES = {
		"Solution::CategoryMeta" => [],
		"Solution::FolderMeta" => [:visibility],
		"Solution::ArticleMeta" => [:art_type]
	}

	META_ASSOCIATIONS = {
		:folder => :category, 
		:article => :folder
	}

	def self.included(base)
		base.send :before_filter, :build_meta_obj, :only => [:create]
	end

	def build_meta_obj
		# To be changed and tested
		# @meta_obj = self.instance_variable_set("@#{cname}_meta", current_account.send(meta_parent).new)
		@meta_obj = current_account.send(meta_parent).new
		assign_meta_attributes
		assign_meta_associations
	end

	def assign_meta_associations
		current_klass = controller_name.singularize.to_sym
		return unless META_ASSOCIATIONS.keys.include?(current_klass)
		@meta_obj.send("solution_#{META_ASSOCIATIONS[current_klass]}_meta=", instance_variable_get("@#{META_ASSOCIATIONS[current_klass]}_meta"))
	end

	def assign_meta_attributes
		META_ATTRIBUTES[@meta_obj.class.name].each do |attribute|
			@meta_obj[attribute] = params[nscname][attribute]
		end
		@meta_obj.account_id = current_account.id
	end

end
