class BaseDelegator < SimpleDelegator
  include ActiveModel::Validations

  attr_accessor :error_options

  def initialize(record)
    super(record)
    @error_options = {}
  end

  # Set true for instance_variable_set if it is part of request params.
  # Say if request params has forum_type, forum_type_set attribute will be set to true.
  def check_params_set(request_params)
    request_params.each_pair do |key, value|
      instance_variable_set("@#{key}_set", true)
    end
  end

  def attr_changed?(att, record = self)
    # changed_attributes gives a hash, that is already constructed when the attributes are assigned.
    # in Rails 3.2 changed_attributes is a Hash, hence exact strings are required.
    # Faster than using changed(changed_attributes.keys), would have been faster if changed_attributes were a HashWithIndifferentAccess
    record.changed_attributes.key? att
  end
end
