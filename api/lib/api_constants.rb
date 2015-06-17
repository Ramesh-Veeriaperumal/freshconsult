module ApiConstants
  # *********************************-- ControllerConstants --*********************************************

  API_CURRENT_VERSION = 'v2'
  DEFAULT_PAGINATE_OPTIONS = {
    per_page: 30,
    page: 1
  }

  # *********************************-- ValidationConstants --*********************************************

  BOOLEAN_VALUES = ['0', 0, false, '1', 1, true] # for boolean fields all these values are accepted.
end
