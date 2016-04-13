# This is needed to make Meta.as_json similar to their children's as_json
# Got more complicated coz ActiveRecord as_json doesn't consider :include's as_json
# https://github.com/rails/rails/pull/2200

module Solution::ApiDelegator
  extend ActiveSupport::Concern
  
  API_ALWAYS_REMOVE = [
    :account_id, :import_id,
    :available, :draft_present, :published, :outdated,
    :solution_category_meta_id, :solution_folder_meta_id, :solution_article_id,
    :language_id, :parent_id, :bool_01, :datetime_01, :delta, :int_01, :int_02, :int_03,
    :string_01, :string_02, :current_child_id
  ]
  
  CHILD_ATTRIBUTES = {
    :category_meta => [:name, :description],
    :folder_meta => [:name, :description],
    :article_meta => [:title, :description, :desc_un_html, :status, :hits, :modified_at, :modified_by, :seo_data, :user_id]
  }
  
  # Order of the keys in the 2nd level should not be changed.
  PARENT_ASSOCIATIONS = {
    :article_meta => {:folder => :solution_folder_meta},
    :folder_meta => {:category => :solution_category_meta}
  }
  
  CHILD_ASSOCIATIONS = {
    :category_meta => { :folders => :solution_folder_meta, :public_folders => :public_folder_meta },
    :folder_meta => { :articles => :solution_article_meta, :published_articles => :published_article_meta},
    :article_meta => { :tags => :tags }
  }
  
  included do |base|
    base_name = base.name.chomp('Meta').gsub("Solution::", '').downcase
    if PARENT_ASSOCIATIONS["#{base_name}_meta".to_sym].present?
      parent_attribute = PARENT_ASSOCIATIONS["#{base_name}_meta".to_sym].keys.first
      base.alias_attribute "#{parent_attribute}_id", "solution_#{parent_attribute}_meta_id"
    end
  end
  
  def as_json(options = {})
    options = options.deep_dup.with_indifferent_access
    parent_json = json_from_parent(options)
    children_json = json_from_children(options)
    primary_json = self.send("primary_#{api_root_name}").as_json({
        :only => CHILD_ATTRIBUTES[class_api_name],
        :except => (options[:except] || []) + [:id] 
      })[api_root_name]

    options[:except] = (options[:except] || []) + API_ALWAYS_REMOVE
    options[:methods] = (options[:methods] || []) + ["#{PARENT_ASSOCIATIONS[class_api_name].keys.first}_id"] if PARENT_ASSOCIATIONS[class_api_name]

    final_resp = super(options.merge(:root => false)).merge(primary_json).merge(parent_json).merge(children_json)
    if (options.key?(:root) && (options[:root] == false))
      final_resp
    else
      final_root_name = options[:to_xml] ? xml_api_root_name : api_root_name
      { options[:root] || final_root_name => final_resp }
    end
  end

  def to_xml(options = {})
    options[:to_xml] = true
    self.as_json(options.except(:builder, :root, :indent))[xml_api_root_name].to_xml( :root => xml_api_root_name)
  end
  
  private
  
  def json_from_parent(options={})
    parent_json = {}
    options = options.dup.with_indifferent_access
    return parent_json if PARENT_ASSOCIATIONS[class_api_name].blank?
    PARENT_ASSOCIATIONS[class_api_name].keys.each do |parent_assoc|
      parent_options = api_includes(parent_assoc, options)
      next unless parent_options
      parent_json.merge!({
        parent_assoc => self.send(PARENT_ASSOCIATIONS[class_api_name][parent_assoc]).as_json(
            parent_options.merge!({:root => false}))
      })
    end
    parent_json
  end
  
  def json_from_children(options={})
    children_json = {}
    options = options.dup.with_indifferent_access
    return children_json if CHILD_ASSOCIATIONS[class_api_name].blank?
    CHILD_ASSOCIATIONS[class_api_name].keys.each do |child_assoc|
      child_options = api_includes(child_assoc, options)
      next unless child_options

      child_options.merge!(:root => false)
      if options.key?(:to_xml)
        child_options.merge!(:to_xml => true) 
        root_key = "solution-" + CHILD_ASSOCIATIONS[class_api_name].keys.first.to_s.singularize
      end
      child_options.merge!(:except => [:tags]) if (class_api_name == :folder_meta)
      
      children_json.merge!({
        child_assoc => (self.send(CHILD_ASSOCIATIONS[class_api_name][child_assoc]).collect do |child|
          child_json = child.as_json(child_options)
          options.key?(:to_xml) ? Solution::ApiXmlResponse.new(child_json.merge(:root => root_key)) : child_json
        end)
      })
    end

    children_json
  end
  
  def api_includes(association, options)
    if (options[:include] === association || options[:include] === association.to_s) || (options[:include].is_a?(Array) && (options[:include].include?(association) || options[:include].include?(association.to_s)))
			return {}
		elsif options[:include].is_a?(Hash) && (options[:include][association].present? || options[:include][association.to_s].present?)
      return options[:include][association]
		end
    return false
  end
  
  def class_api_name
    @class_api_name ||= self.class.name.underscore.gsub('solution/','').to_sym
  end
  
  def api_root_name
    @api_root_name ||= class_api_name.to_s.gsub('_meta', '')
  end

  def xml_api_root_name
    "solution_#{api_root_name}"
  end
end
