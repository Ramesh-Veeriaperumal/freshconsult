module PrivilegesHelper
  def add_privilege(user, privilege)
    user.privileges = (user.privileges.to_i | (1 << PRIVILEGES[privilege])).to_s
    user.save
  end

  def remove_privilege(user, privilege)
    user.privileges = (user.privileges.to_i & ~(1 << PRIVILEGES[privilege])).to_s
    user.save
  end

  def toggle_privilege(user, privilege)
    user.privileges = (user.privileges.to_i ^ (1 << PRIVILEGES[privilege])).to_s
    user.save
  end
end