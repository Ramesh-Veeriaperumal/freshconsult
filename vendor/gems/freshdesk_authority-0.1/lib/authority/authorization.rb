require 'authority/mapper'

module Authority
  module Authorization
    # PrivilegeList is a Mapper object, it's declared a constant so that it is
    # initialized only once in the applications lifetime
    PrivilegeList = Mapper.new
    Keeper = Bookkeeper.new('privileges.yml')
  end
end