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
		@params = @args["#{obj}_meta"] || @args[obj]
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
		return if @params["#{parent_of(obj)}_meta"].blank?
		@meta_obj.send("#{parent_of(obj)}_meta=", Solution::Object.new(@params, parent_of(obj), @meta_obj).object)
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
	
	def short_name(context_obj = nil)
		(context_obj || obj).to_s.gsub('solution_', '')
	end

	def build_meta
		@meta_obj = @params[:id].blank? ? new_meta : initialize_meta
		assign_meta_attributes
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

	def new_parent?
		@params["#{parent_of(obj)}_meta_id"].blank? && (@params["#{parent_of(obj)}_meta"].present? && @params["#{parent_of(obj)}_meta"]["id"].blank?)
	end	

	def assign_meta_attributes
		META_ATTRIBUTES[@obj].each do |attribute|
			@meta_obj.send("#{attribute}=", @params.delete(attribute)) if @params[attribute].present?
		end
		@meta_obj.account_id = Account.current.id
	end

  def handle_parent_change
    attribute = params["#{parent_of(obj)}_meta_id"].present? ? "#{parent_of(obj)}_meta_id" : "#{short_name(parent_of(obj))}_id"
    return unless parent_of(obj).present? && params[attribute].present?
    assign_new_parent(attribute)
  end

  def assign_new_parent(attribute)
    parent = Account.current.send("#{parent_of(obj)}_meta").find_by_id(params[attribute])
    raise "#{parent_of(obj)} id not valid" if parent.blank?
    @meta_obj.send("#{parent_of(obj)}_meta_id=", params.delete(attribute))
  end
	
	def build_translations
		@objects = []
		languages.map { |lang| build_for(lang)}
	end
	
	def build_for(lang)
		object = @meta_obj.send("#{lang}_#{short_name}") || @meta_obj.send("build_#{lang}_#{short_name}") 
		params_for(lang).except(:id, :tags).each do |k,v|
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
    return unless p.present?
		p.reject{|k,v| ASSOCIATIONS.include?(k.to_sym) }
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

  def parent_of(obj)
    META_ASSOCIATIONS[obj]
  end

end