class Solution::ApiXmlResponse

  include ActiveModel::Serializers::Xml

  attr_accessor :all_data, :root

  def initialize(attributes = {})
    self.all_data = attributes.with_indifferent_access
    self.root = all_data[:root]
    self.all_data.delete(:root)
  end

  def method_missing(*args)
    all_data[args.first]
  end

  def attributes
    all_data
  end

  def to_xml(options = {})
    options[:root] = root
    super(options)
  end

end