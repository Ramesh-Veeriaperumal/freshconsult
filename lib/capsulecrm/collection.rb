class CapsuleCRM::Collection < Array


  def initialize
    super
  end
  
  # nodoc
  def initialize(klass, data)
    return if data.nil?
    [data].flatten.each do |attributes|
      attributes = klass.attributes_from_xml_hash(attributes)
      self.push klass.new(attributes)
    end
  end


end
