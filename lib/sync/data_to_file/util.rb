module Sync::DataToFile::Util
  def self.included(base)
    [Sync::CustomLogger, Sync::Util, Sync::Constants, Sync::Transformer::Util, Sync::SqlUtil].each do |file|
      base.send(:include, file)
      base.include  InstanceMethods
    end
  end

  module InstanceMethods
    def transfrom_id(transformer, data, model)
      if sandbox && transformer.available_id?(model)
        sync_logger.info('*' * 100 + "  ---- Transforming id for create file model: #{model}")
        data = transformer.safe_send("transform_#{model.gsub('::', '').snakecase}_id", data).to_s
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
