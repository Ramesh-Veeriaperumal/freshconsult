class CapsuleCRM::CustomField < CapsuleCRM::Base

  attr_accessor :boolean
  attr_accessor :date
  attr_accessor :label
  attr_accessor :text
  attr_accessor :tag


  # nodoc
  def boolean=(value)
    return @boolean = true if value.to_s == 'true'
    @boolean = false
  end


  # nodoc
  def date=(value)
    value = Time.parse(value) if value.is_a?(String)
    @date = value
  end


  # nodoc
  def value
    date || text || boolean
  end
  
  def attributes_hash
    hsh = {  "label" => label ,
             "tag" => tag  }
    hsh[:text] = text unless text.blank?
    hsh[:date] = date unless date.blank?
    hsh
  end
  
  # nodoc
  def self.xml_map
    map = {
      'label' => 'label',
      'text' => 'text',
      'date' => 'date',
      'boolean' => 'boolean',
      'tag' => 'tag'
    }
    super.merge map
  end


end
