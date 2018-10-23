module Sync::DataToFile::Util
  def self.included(base)
    [Sync::Util, Sync::Constants, Sync::Transformer::Util, Sync::SqlUtil].each do |file|
      base.send(:include, file)
      base.include  InstanceMethods
    end
  end

  module InstanceMethods
    def transform_id(transformer, data, model, reverse = false)
      if sandbox && (can_transform = !@transformer.skip_transformation?(data))
        old_data = data
        data = transformer.apply_id_mapping(old_data, {}, '', reverse)
        Sync::Logger.log('*' * 100 + "  ---- Transforming id for create file model: #{model}, old_data = #{old_data.inspect}, new_data = #{data.inspect}, reverse = #{reverse.inspect}")
      end
      data
    end

    def model_name(object)
      model = object.class.superclass.to_s != 'ActiveRecord::Base' ? object.class.superclass.to_s : object.class.name
      model = 'VaRule' if model == 'VARule'
      model
    end
  end
end
