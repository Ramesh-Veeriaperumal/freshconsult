class Sync::FileToData::ModelDirectories
  include Sync::Constants
  include Sync::Util
  attr_accessor :account, :path
  def initialize(path, clone, account = Account.current)
    @path = path
    @account = account
    @clone = clone
    @model_directories = {}
  end

  def perform
    all_relations = RELATIONS
    all_relations += CLONE_RELATIONS if @clone
    all_relations.each do |relation|
      directories_for_model(relation[0])
    end
    @model_directories
  end

  private

    def directories_for_model_util(path, object)
      return {} unless File.directory?(path)
      table_directory = {}
      association = File.basename(File.dirname(path))
      if association.gsub(/.*_([^_]+)$/, '\1').to_i.zero?
        object = object.class.reflections[association.to_sym].klass.new
        model_name = model_name(object)
        table_directory[model_name] ||= []
        table_directory[model_name] << path if Dir.entries(path).select { |f| File.file?(File.join(path, f)) && !['.DS_Store'].include?(f) }.any? # Need to re write
      end
      traverse_directory(path) do |item|
        object_path = File.join(path, item)
        if File.directory?(object_path)
          table_directory.merge!(directories_for_model_util(object_path, object)) { |key, this_val, other_val| [*this_val, other_val].flatten.uniq }
        end
      end
      table_directory
    end

    def directories_for_model(association)
      dir_path = File.join(path, association)
      return {} unless File.directory?(dir_path)
      object = account.class.reflections[association.to_sym].klass.new
      model_name = object.class.name
      @model_directories[model_name] ||= {}
      traverse_directory(dir_path) do |item|
        object_path = File.join(dir_path, item)
        @model_directories[model_name][item] = directories_for_model_util(object_path, account)
      end
    end

    def model_name(object)
      model = object.class.superclass.to_s != 'ActiveRecord::Base' ? object.class.superclass.to_s : object.class.name
      model = 'Helpdesk::Source' if model == 'Helpdesk::Choice'
      model
    end
end
