class BaseDelegator < SimpleDelegator
  include ActiveModel::Validations

  attr_accessor :error_options

  def initialize(record)
    super(record)
    @error_options = {}
  end

  def attr_changed?(att, record = self)
    # changed_attributes gives a hash, that is already constructed when the attributes are assigned.
    # in Rails 3.2 changed_attributes is a Hash, hence exact strings are required.
    # Faster than using changed(changed_attributes.keys), would have been faster if changed_attributes were a HashWithIndifferentAccess
    record.changed_attributes.key? att
  end
end
