class Solution::Object
	
	META_ATTRIBUTES = {
		:solution_category => [],
		:solution_folder => [:visibility],
		:solution_article => [:art_type, :user_id]
	}

	META_ASSOCIATIONS = {
		:solution_folder => :solution_category, 
		:solution_article => :solution_folder
	}

	attr_accessor :args, :obj, :param_name

	def initialize(args, obj)
		@args = args
		@obj = obj
	end

	def solution_obj
		build_meta_obj
		build_obj
		add_errors unless @meta_obj.save
		@solution_obj
	end

	def build_meta_obj
		@meta_obj = Account.current.send("#{obj}_meta").find_or_initialize_by_id(args[obj] && args[obj][:parent_id])
		return if args[obj].blank? || !@meta_obj.new_record?
		assign_meta_attributes(obj)
		assign_meta_associations(obj)
	end

	def build_obj
		@solution_obj = @meta_obj.send(obj.to_s.pluralize).new(args[obj])
		@solution_obj.language_id = (args[obj] && args[obj][:language_id]) || Language.for_current_account
	end

	def assign_meta_associations
		return unless META_ASSOCIATIONS.keys.include?(obj)
		@meta_obj.send("#{META_ASSOCIATIONS[obj]}_meta=", get_parent_association(obj))
	end

	def assign_meta_attributes
		META_ATTRIBUTES[obj].each do |attribute|
			@meta_obj[attribute] = args[obj][attribute]
			@meta_obj[attribute] ||= User.current.id if attribute.eql?(:user_id)
		end
		@meta_obj.account_id = Account.current.id
	end

	def get_parent_association
		return unless args[obj]["#{META_ASSOCIATIONS[obj]}_id".to_sym].present?
		Account.current.send("#{META_ASSOCIATIONS[obj]}_meta").find_by_id(args[obj]["#{META_ASSOCIATIONS[obj]}_id".to_sym])
	end

	def add_errors
		@solution_obj.errors.add(@meta_obj.class.name.to_sym, @meta_obj.errors.messages)
	end

end