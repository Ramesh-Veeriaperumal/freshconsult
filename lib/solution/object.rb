class Solution::Object
	
	META_ATTRIBUTES = {
		:solution_category => [:is_default, :portal_ids],
		:solution_folder => [:visibility, :is_default, :companies], #Find the right attr for CustomerFolders
		:solution_article => [:art_type]
	}

	META_ASSOCIATIONS = {
		:solution_folder => :solution_category, 
		:solution_article => :solution_folder
	}
	
	PREFIXES = Language.all.collect(&:name).collect(&:to_s).prepend('primary')

	attr_accessor :args, :obj, :params

	def initialize(args, obj)
		puts "*" * 100
		puts "ARgs"
		puts args.inspect
		puts "obj"
		puts obj.inspect
		puts  'args["#{obj}_meta"]'
		puts "#{obj}_meta"
		puts args["#{obj}_meta"].inspect
		throw "Invalid Object Type" unless META_ATTRIBUTES.keys.include?(obj.to_sym)
		@params = (args[obj] || args["#{obj}_meta"])
	
		puts "Paraams"
		puts @params.inspect
		puts "*" * 100
		@args = args
		
		
		
		@obj = obj
	end

	def return_back
		build_meta
		build_translations
		@meta_obj.save
		response
	end
	
	private
	
	def meta_params
		puts "-" * 100
		puts @params.inspect
		puts "-" * 100
		
		@meta_params_found ||= @params.slice(META_ATTRIBUTES[obj])
	end
	
	def primary_params
		params["primary_#{short_name}"] || params.reject { |k,v| META_ATTRIBUTES[obj].include?(k) }
	end
	
	def languages
		@detected_languages ||= begin
			langs = params.keys.collect { |k| k.gsub(short_name) }.compact & PREFIXES
			langs || ['primary']
			# Make sure, we check if multiple languages are supported for this account
		end
	end
	
	def short_name
		@short_name_cached ||= obj.gsub('solution_', '')
	end

	def build_meta
		meta_params.inspect
		@meta_obj = meta_params[:id].blank? new_meta || initialize_meta
		assign_meta_attributes(obj)
		@meta_obj.is_default = false if @meta_obj.responds_to?(:is_default)
	end
	
	def new_meta
		Account.current.send("#{obj}_meta").new
	end
	
	def initialize_meta
		Account.current.send("#{obj}_meta").find_by_id(meta_params[:id]) || raise('Meta object not found')
	end

	def assign_meta_associations
		return unless META_ASSOCIATIONS.keys.include?(obj)
		@meta_obj.send("#{META_ASSOCIATIONS[obj]}_meta=", get_parent_association(obj))
	end

	def assign_meta_attributes
		META_ATTRIBUTES[obj].each do |attribute|
			@meta_obj[attribute] = meta_params[attribute]
		end
		@meta_obj.account_id = Account.current.id
	end
	
	def build_translations
		@objects = []
		languages.each do |lang|
			lang == 'primary' ? create_primary : create_translation(lang)
		end
	end
	
	def create_primary
		object = build_object("primary_#{short_name}")
		primary_params.each do |k,v|
			object.send(k, v)
		end
		@objects << object
	end
	
	def create_translation(lang)
		object = build_object("#{lang}_#{short_name}")
		primary_params.each do |k,v|
			object.send(k, v)
		end
		@objects << @meta_obj.send("build_#{lang}_#{short_name}", meta_params["#{lang}_#{short_name}"])
	end
	
	def build_object(assoc_name)
		@meta_obj.send("#{assoc_name}") || @meta_obj.send("build_#{assoc_name}") 
	end
	
	def response
		if @objects.size == 1
			response = @objects.first
			response.errors.add(@meta_obj.class.name.to_sym, @meta_obj.errors.messages) if @meta_obj.errors.messages.any?
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