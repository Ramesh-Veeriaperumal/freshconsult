class CapsuleCRM::Person < CapsuleCRM::Party

  attr_accessor :about
  attr_accessor :name
  attr_accessor :job_title
  attr_accessor :last_name
  attr_accessor :organisation_id
  attr_accessor :title
  attr_accessor :organisation_name
  attr_accessor :email
  attr_accessor :phone



  #define_attribute_methods [:about, :first_name, :last_name, :job_title, :organisation_name, :title,:email,:organisation_id]


  # nodoc
  def attributes
    attrs = {}
    arr = [:about, :name, :last_name, :title, :job_title,:organisation_name,:email,:organisation_id,:phone]
    arr.each do |key|
      attrs[key] = self.send(key)
    end
    attrs
  end
  
  # nodoc
  def first_name=(value)
    @first_name = value
  end


  # nodoc
  def last_name=(value)
    @last_name = value
  end


  # nodoc
  def title=(value)
    @title = value
  end


  # nodoc
  def organisation
    return nil if organisation_id.nil?
    @organisation ||= CapsuleCRM::Organisation.find(organisation_id)
  end


  # nodoc
  def save
    new_record?? create : update
  end


  private


  # nodoc
  def create
    return false if attributes.empty?
    path = '/api/person'
    options = {:root => 'person', :path => path}
    hsh = attributes_hash
    xml_out = hsh.to_xml :root => 'person'
    new_id = self.class.create xml_out, options
    unless new_id
      errors << self.class.last_response.response.message
      return false
    end
    @errors = []
    self.id = new_id
  end
  
  def attributes_hash
    hsh = {  "firstName" => name ,
             "contacts" => {"email" => {"emailAddress" => email, "type" => "Work"}, "phone" => {}} ,
             "organisationId" => organisation_id }
    hsh["contacts"]["phone"] =  {"phoneNumber" => phone, "type" => "Work"} unless phone.blank?
    hsh
  end


  # nodoc
  def dirty_attributes
    Hash[attributes.select { |k,v| changed.include? k.to_s }]
  end


  # nodoc
  def update
    path = '/api/person/' + id.to_s
    options = {:root => 'person', :path => path}
    success = self.class.update id, dirty_attributes, options
    success
  end


  # -- Class methods --

  
  # nodoc
  def self.init_many(response)
    data = response['parties']['person']
    data
    CapsuleCRM::Collection.new(self, data)
  end


  # nodoc
  def self.init_one(response)
    data = response['person']
    new(attributes_from_xml_hash(data))
  end


  # nodoc
  def self.xml_map
    map = {
      'about' => 'about',
      'firstName' => 'first_name',
      'jobTitle' => 'job_title',
      'lastName' => 'last_name',
      'organisationId' => 'organisation_id',
      'organisationName' => 'organisation_name',
      'title' => 'title'
    }
    super.merge map
  end


end
