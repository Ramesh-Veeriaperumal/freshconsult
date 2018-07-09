class Sync::FileToData::ModelInsertOrder
  include Sync::Constants
  def self.find
    # For clone or selected columns we need to calculate model insert based on config selection
    # For now we can use static model insert order which we define in sync constants
    MODEL_INSERT_ORDER
  end
end
