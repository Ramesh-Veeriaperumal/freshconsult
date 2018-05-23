module PrivilegesHelper
  def add_privilege(user, privilege)
    user.privileges = (user.privileges.to_i | (1 << PRIVILEGES[privilege])).to_s
    user.save(validate: false)
  end

  def remove_privilege(user, privilege)
    user.privileges = (user.privileges.to_i & ~(1 << PRIVILEGES[privilege])).to_s
    user.save(validate: false)
  end

  def toggle_privilege(user, privilege)
    user.privileges = (user.privileges.to_i ^ (1 << PRIVILEGES[privilege])).to_s
    user.save(validate: false)
  end
end