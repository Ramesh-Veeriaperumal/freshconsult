module Dashboard::Custom
  module GridConfig

    GRID_ATTRIBUTES = [:x, :y, :height, :width].freeze
    GRID_ATTRIBUTES.each do |attribute|
      define_method("#{attribute}=") do |updated_value|
        merge_grid_config("#{attribute}" => updated_value)
      end
    end

    private

      def merge_grid_config(updated_config)
        self.grid_config = HashWithIndifferentAccess.new(self.grid_config.merge(updated_config))
      end
  end
end
