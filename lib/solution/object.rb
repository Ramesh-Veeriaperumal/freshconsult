class Solution::Object

	include CloudFilesHelper
	
	META_ATTRIBUTES = {
		:solution_category => [:is_default, :portal_ids, :portals],
		:solution_folder => [:visibility, :is_default, :customer_folders_attributes],
		:solution_article => [:art_type]
	}

	META_ASSOCIATIONS = {
		:solution_folder => :solution_category, 
		:solution_article => :solution_folder
	}
	
	PREFIXES = Language.all.collect(&:to_key).collect(&:to_s).prepend('primary')

	ASSOCIATIONS = [:attachments, :cloud_file_attachments]

	attr_accessor :args, :obj, :params

	def initialize(args, obj, child = nil)
		throw "Invalid Object Type" unless META_ATTRIBUTES.keys.include?(obj.to_sym)
		@args = args
		@obj = obj
		@params = get_params
		@child = child
	end

	def object
		build_meta
		build_translations
		create_parent_translation
		if save_check?
			@meta_obj.save
		end 
		@meta_obj
	end
	
	private

	def create_parent_translation
		return if @params["#{META_ASSOCIATIONS[obj]}_meta"].blank?
		Solution::Object.new(@params, META_ASSOCIATIONS[obj], @meta_obj).object
	end
	
	def meta_params	
		@meta_params_found ||= @params.slice(*META_ATTRIBUTES[obj])
	end
	
	def primary_params
		params["primary_#{short_name}"] || params.reject { |k,v| META_ATTRIBUTES[obj].include?(k) }
	end

	def save_check?
		@child.present? ? true : primary_version_check?
	end
	
	def languages
		@detected_languages ||= begin
			langs = @params.keys & PREFIXES.collect{|s| "#{s}_#{short_name}"}
			langs.collect! { |k| k.gsub("_#{short_name}", '') }.compact!
			# Make sure, we check if multiple languages are supported for this account
			langs.concat(['primary']).uniq if langs.blank?
			langs
		end
	end
	
	def short_name
		@short_name_cached ||= obj.to_s.gsub('solution_', '')
	end

	def build_meta
		@meta_obj = @params[:id].blank? ? new_meta : initialize_meta
		assign_meta_attributes
		assign_meta_associations
		handle_parent_change
	end
	
	def new_meta
		return @child.send("build_#{obj}_meta") if @child.present?
		Account.current.send("#{obj}_meta").new
	end
	
	def initialize_meta
		return @child.send("#{obj}_meta") || @child.send("build_#{obj}_meta", @params) if @child.present?
		Account.current.send("#{obj}_meta").find_by_id(@params[:id]) || raise('Meta object not found')
	end

	def assign_meta_associations
		return unless @meta_obj.new_record? && META_ASSOCIATIONS.keys.include?(obj)
		return if new_parent?
		@meta_obj.send("#{META_ASSOCIATIONS[obj]}_meta=", get_parent_association)
	end

	def get_parent_association
		raise "#{META_ASSOCIATIONS[obj]} id not specified" unless @params["#{META_ASSOCIATIONS[obj]}_meta_id"].present?
		Account.current.send("#{META_ASSOCIATIONS[obj]}_meta").find_by_id(@params["#{META_ASSOCIATIONS[obj]}_meta_id"])
	end

	def new_parent?
		@params["#{META_ASSOCIATIONS[obj]}_meta_id"].blank? && (@params["#{META_ASSOCIATIONS[obj]}_meta"].present? && @params["#{META_ASSOCIATIONS[obj]}_meta"]["id"].blank?)
	end	

	def assign_meta_attributes
		META_ATTRIBUTES[@obj].each do |attribute|
			@meta_obj.send("#{attribute}=", @params.delete(attribute)) if @params[attribute].present?
		end
		@meta_obj.account_id = Account.current.id
	end

	def handle_parent_change
		attribute = "#{META_ASSOCIATIONS[obj]}_meta_id"
		return unless @params[attribute].present?
		parent = Account.current.send("#{META_ASSOCIATIONS[obj]}_meta").find_by_id(@params[attribute])
		raise "#{META_ASSOCIATIONS[obj]} id not valid" if parent.blank?
		@meta_obj.send("#{attribute}=", @params.delete(attribute))
	end
	
	def build_translations
		@objects = []
		languages.map { |lang| build_for(lang)}
	end
	
	def build_for(lang)
		object = @meta_obj.send("#{lang}_#{short_name}") || @meta_obj.send("build_#{lang}_#{short_name}") 
		params_for(lang).each do |k,v|
			object.send("#{k}=", v)
		end
		build_associations(object, lang)
		@objects << object
	end
	
	def params_for(lang)
		return filter(@params["#{lang}_#{short_name}"]) unless lang == 'primary'
		filter(@params["primary_#{short_name}"]) || @params.reject { |k,v| META_ATTRIBUTES[obj].include?(k) }
	end

	def filter p
		p.reject{|k,v| ASSOCIATIONS.include?(k.to_sym) }
	end

	def build_associations object, lang
		attachment_builder(object, 
			@params["#{lang}_#{short_name}"][:attachments], 
			@params["#{lang}_#{short_name}"][:cloud_file_attachments] )
	end

	def handle_errors
		@solution_obj.errors.add(@meta_obj.class.name.to_sym, @meta_obj.errors.messages)
	end

	def primary_version_check?
		primary_check = true
		if @meta_obj.new_record?
			langs = languages
			primary_check = langs.include?('primary') || langs.include?(Account.current.language)
			@meta_obj.errors.add(@meta_obj.class.name.to_sym, {:primary_version => "attributes can't be blank"}) if primary_check
		end
		primary_check
	end

	def get_params
		return @args["#{@obj}_meta"] if @args["#{@obj}_meta"].present?
		#handling old param structure (From API)
		modify_old_params
	end

	def modify_old_params
		params = HashWithIndifferentAccess.new
		if @args["#{@obj}"].present?
			old_params = @args["#{@obj}"].dup
			(META_ATTRIBUTES[@obj] + [:id]).each do |m_att|
				params[m_att] = old_params.delete(m_att) if old_params.key?(m_att)
			end
			parent_attr = META_ASSOCIATIONS[@obj].to_s.gsub('solution_', '')
			params["#{META_ASSOCIATIONS[@obj]}_meta_id"] = old_params.delete("#{parent_attr}_id") if old_params["#{parent_attr}_id"].present?
			params.merge!({"primary_#{short_name}" => old_params})
		end
		params
	end

end