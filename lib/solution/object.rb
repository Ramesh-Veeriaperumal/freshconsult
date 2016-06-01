class Solution::Object

	include CloudFilesHelper
	
	META_ATTRIBUTES = {
		:solution_category => [:is_default, :portal_ids, :portals],
		:solution_folder => [:visibility, :is_default, :customer_folders_attributes],
		:solution_article => [:art_type]
	}

	PARENT_OF = {
		:solution_folder => :solution_category, 
		:solution_article => :solution_folder
	}

	VERSION_ATTRIBUTES = {
		:solution_category => [:name, :description, :import_id],
		:solution_folder => [:name, :description, :import_id],
		:solution_article => [:title, :description, :user_id, :status, :import_id, :seo_data, :outdated, :thumbs_up, :thumbs_down]
	}
	
	PREFIXES = Language.all.collect(&:to_key).collect(&:to_s).prepend('primary')

	ASSOCIATIONS = [:attachments, :cloud_file_attachments]

	attr_accessor :args, :obj, :params, :meta_obj, :child, :objects

	def initialize(args, obj, child = nil)
		throw "Invalid Object Type" unless META_ATTRIBUTES.keys.include?(obj.to_sym)
		@args = args
		@obj = obj
		@params = @args["#{obj}_meta"] || @args[obj]
		@child = child
	end

	def object
		build_meta
		build_translations
		create_parent_translation
		if save_check?
			@meta_obj.save
             add_errors_to_base
		end
		@meta_obj
	end
	
	private

	def build_meta
		@meta_obj = @params[:id].blank? ? new_meta : initialize_meta
		assign_meta_attributes
		handle_parent_change
	end
  
	def build_translations
		@objects = []
		languages.map { |lang| build_for(lang)}
	end

	def create_parent_translation
		return if PARENT_OF[obj].blank? || @params["#{PARENT_OF[obj]}_meta"].blank?
    @params["#{PARENT_OF[obj]}_meta"]['id'] = @meta_obj.send("#{PARENT_OF[obj]}_meta_id") if @meta_obj.send("#{PARENT_OF[obj]}_meta_id")
		@meta_obj.send("#{PARENT_OF[obj]}_meta=", Solution::Object.new(@params, PARENT_OF[obj], @meta_obj).object)
	end
  
  
  def new_meta
    @child.try("build_#{obj}_meta") ||
        Account.current.send("#{obj}_meta").new
  end
  
  def initialize_meta
    return @child.send("#{obj}_meta") || @child.send("build_#{obj}_meta") if @child.present?
    Account.current.send("#{obj}_meta").find_by_id(@params[:id]) || raise('Meta object not found')
  end

	def assign_meta_attributes
		META_ATTRIBUTES[@obj].each do |attribute|
			@meta_obj.send("#{attribute}=", @params.delete(attribute)) if @params[attribute].present?
		end
		@meta_obj.account_id = Account.current.id
	end

  def handle_parent_change
    attribute = params["#{PARENT_OF[obj]}_meta_id"].present? ? "#{PARENT_OF[obj]}_meta_id" : "#{short_name(PARENT_OF[obj])}_id"
    return unless PARENT_OF[obj].present? && params[attribute].present?
    assign_new_parent(attribute)
  end
  
  def save_check?
		@child.present? ? false : primary_version_check?
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
	
	def build_for(lang)
		object = @meta_obj.send("#{lang}_#{short_name}") || @meta_obj.send("build_#{lang}_#{short_name}") 
		params_for(lang).slice(*VERSION_ATTRIBUTES[obj]).each do |k,v|
			object.send("#{k}=", v)
		end
		build_associations(object, lang)
		@objects << object
	end
  
	def short_name(context_obj = nil)
		(context_obj || obj).to_s.gsub('solution_', '')
	end
	
	def params_for(lang)
		return filter(@params["#{lang}_#{short_name}"]) unless lang == 'primary'
		filter(@params["primary_#{short_name}"]) || @params.reject { |k,v| META_ATTRIBUTES[obj].include?(k.to_sym) }
	end

	def filter p
    return unless p.present?
		p.reject{|k,v| ASSOCIATIONS.include?(k.to_sym) || META_ATTRIBUTES[obj].include?(k.to_sym) }
	end

	def build_associations object, lang
		attachment_builder(object, 
			(@params["#{lang}_#{short_name}"] || {})[:attachments], 
			(@params["#{lang}_#{short_name}"] || {})[:cloud_file_attachments] )
	end

	def primary_version_check?
    return true unless @meta_obj.new_record?
    primary_check = languages.include?('primary') || languages.include?(Account.current.language)
    @meta_obj.errors.add(:primary_version, "attributes can't be blank") unless primary_check
    primary_check
	end
  
  def assign_new_parent(attribute)
    parent = Account.current.send("#{PARENT_OF[obj]}_meta").find_by_id(params[attribute])
    raise "#{PARENT_OF[obj]} id not valid" if parent.blank?
    @meta_obj.send("#{PARENT_OF[obj]}_meta_id=", params.delete(attribute))
  end

  def add_errors_to_base
    # We are assuming that we are dealing with only one language version of a solution item or a set of solution 
    # items at any point of time. In future, if we are dealing with multiple language versions in the same form, this
    # method won't be compatible with that, but other methods might be compatible.

    return unless @meta_obj.errors.present?
    entities = ['article', 'folder', 'category']
    #expression to match version attributes eg: :"zh_tw_category.name"
    exp_vers = Hash.new { |h, k| h[k] = /(\w+)_#{k}$/i }
    #expression to match meta attributes eg: :"solution_folder_meta.visibility"
    exp_meta = Hash.new { |h, k| h[k] = /solution_#{k}_meta$/i  }
    errors_of = @meta_obj.errors.messages.keys

    errors_of.each do |key|
      # We need only last two attributes in the error message key to identify the solution object and it's attribute
      # eg: :"solution_article_meta.solution_folder_meta.solution_category_meta.zh_tw_category.name"
      # to make sense out of the above key we need only "zh_tw_category.name" part.
      entity_attr = key.to_s.split('.').last(2)
      if entity_attr.size > 1
        entities.each do |entity|
          if exp_vers[entity].match(entity_attr.first) || exp_meta[entity].match(entity_attr.first)
            # Convert eg: :"zh_tw_category.name" => "category.name" or
            # convert eg: :"solution_folder_meta.visibility" => "folder.visibility"
            @meta_obj.errors.messages[:"#{entity}.#{entity_attr[1]}"] = @meta_obj.errors.messages.delete(key)
            break
          end
        end
      else
        # To change :"visibility" to :"folder.visibility"
        @meta_obj.errors.messages[:"#{short_name}.#{entity_attr[0]}"] = @meta_obj.errors.messages.delete(key)
      end
    end
  end

end