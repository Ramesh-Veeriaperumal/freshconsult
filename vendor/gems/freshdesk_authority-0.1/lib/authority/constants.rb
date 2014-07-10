PRIVILEGES = Authority::Authorization::Keeper.load_privileges
PRIVILEGES_BY_NAME = PRIVILEGES.keys
PRIVILEGES_IN_ORDER = Authority::Authorization::PrivilegeList.privileges_by_name

ABILITIES = Authority::Authorization::PrivilegeList.privileges