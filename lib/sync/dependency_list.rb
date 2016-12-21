module Sync
  class DependencyList < Struct.new(:model_name, :accepted_models)
    attr_accessor :dependency_list

    def construct_dependencies
     @dependency_list = []
      model_name.constantize.reflect_on_all_associations(:belongs_to).each do |association|
        @association = association
        @dependency_list << dependencies if dependencies[:classes].present?
      end
      @dependency_list
    end

    def dependencies
      {
        :classes      => (polymorphic? ? polymorphic_dependencies : Array(klass)) & accepted_models,
        :foreign_key  => foreign_key,
        :polymorphic_type_column => polymorphic_type
      }
    end

    def polymorphic?
      !!@association.options[:polymorphic]
    end    

    def polymorphic_dependencies
      return [] unless polymorphic?
      all_models.select { |model| polymorphic_match? model }.map(&:model_name)
    end

    def polymorphic_match?(model)
      associations = model.reflect_on_all_associations(:has_many) + model.reflect_on_all_associations(:has_one)
      associations.any? do |has_many_association|
        has_many_association.options[:as].to_s == @association.name.to_s || has_many_association.options[:as] == @association.name
      end
    end    

    def klass
      @association.class_name.gsub(/^::/, "") unless polymorphic?
    end

    def name
      @association.options[:class_name] || @association.name
    end

    def foreign_key
      @association.foreign_key
    end

    def polymorphic_type
      @association.foreign_type if polymorphic?
    end

    def all_models
      @all_models ||= ActiveRecord::Base.descendants
    end
  end
end