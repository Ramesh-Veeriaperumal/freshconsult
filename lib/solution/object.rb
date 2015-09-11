class Solution::Object
	
	META_ATTRIBUTES = {
		:solution_category => [:is_default, :portal_ids, :portals],
		:solution_folder => [:visibility, :is_default, :companies], #Find the right attr for CustomerFolders
		:solution_article => [:art_type]
	}

	META_ASSOCIATIONS = {
		:solution_folder => :solution_category, 
		:solution_article => :solution_folder
	}
	
	PREFIXES = Language.all.collect(&:to_key).collect(&:to_s).prepend('primary')

	attr_accessor :args, :obj, :params

	def initialize(args, obj)
		throw "Invalid Object Type" unless META_ATTRIBUTES.keys.include?(obj.to_sym)
		@params = (args[obj] || args["#{obj}_meta"])
		@args = args
		@obj = obj
	end

	def object
		build_meta
		build_translations
		@meta_obj.save
		response
	end
	
	private
	
	def meta_params	
		@meta_params_found ||= @params.slice(*META_ATTRIBUTES[obj])
	end
	
	def primary_params
		params["primary_#{short_name}"] || params.reject { |k,v| META_ATTRIBUTES[obj].include?(k) }
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
	end
	
	def new_meta
		Account.current.send("#{obj}_meta").new
	end
	
	def initialize_meta
		Account.current.send("#{obj}_meta").find_by_id(@params[:id]) || raise('Meta object not found')
	end

	def assign_meta_associations
		return unless META_ASSOCIATIONS.keys.include?(obj)
		@meta_obj.send("#{META_ASSOCIATIONS[obj]}_meta=", get_parent_association(obj))
	end

	def assign_meta_attributes
		META_ATTRIBUTES[@obj].each do |attribute|
			@meta_obj[attribute] = meta_params[attribute] if meta_params[attribute].present?
		end
		@meta_obj.account_id = Account.current.id
		@meta_obj.is_default = false if @meta_obj.respond_to?(:is_default)
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
		@objects << object
	end
	
	def params_for(lang)
		return @params["#{lang}_#{short_name}"] unless lang == 'primary'
		@params["primary_#{short_name}"] || @params.reject { |k,v| META_ATTRIBUTES[obj].include?(k) }
	end
	
	def response
		if @objects.size == 1
			response = @objects.first
			response.errors.add(@meta_obj.class.name.to_sym, @meta_obj.errors.messages) if @meta_obj.errors.messages.any?
			response
		else
			errors = @objects.inject({}) do |res, o|
				res[o.language_id] = o.errors.messages
			end
			errors[@meta_obj.class.name.to_sym] = @meta_obj.errors.messages if @meta_obj.errors.messages.any?
			
			errors.values.compact.blank? ? @objects : errors
		end	
	end

	def handle_errors
		@solution_obj.errors.add(@meta_obj.class.name.to_sym, @meta_obj.errors.messages)
	end

end