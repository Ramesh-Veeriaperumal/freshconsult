class CapsuleCRM::Organisation < CapsuleCRM::Party

  attr_accessor :about
  attr_accessor :name


  # nodoc
  def people
    return @people if @people
    path = self.class.get_path
    path = [path, '/', id, '/people'].join
    last_response = self.class.get(path)
    @people = CapsuleCRM::Person.init_many(last_response)
  end


  # nodoc
  def self.init_many(response)
    data = response['parties']['organisation']
    CapsuleCRM::Collection.new(self, data)
  end


  # nodoc
  def self.init_one(response)
    data = response['organisation']
    new(attributes_from_xml_hash(data))
  end
  
   # nodoc
  def save
    new_record?? create : update
  end
  
  


  # nodoc
  def self.xml_map
    map = {
      'about' => 'about',
      'name' => 'name'
    }
    super.merge map
  end
  
  private
  
  # nodoc
  def create
    return false if name.empty?
    path = '/api/organisation'
    options = {:root => 'organisation', :path => path}
    hsh = attributes_hash
    xml_out = hsh.to_xml :root => 'organisation'
    puts xml_out
    new_id = self.class.create xml_out, options
    unless new_id
      errors << self.class.last_response.response.message
      return false
    end
    @errors = []
    self.id = new_id
  end
  
  def attributes_hash
    hsh = {  "name" => name  }
    hsh
  end

end
