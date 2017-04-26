module ExportTestHelper
  VALID_DATE_FORMATS = ["2017-04-02", "2017-04-02T08:00", "2017-04-02T08:00Z", "2017-04-02T08:00:00", "2017-04-02T08:00:00Z", "2017-04-02T08:00:00+05:30", "2017-04-02T08:00:00+05", "2017-04-02T08:00:00+0530"]

  INVALID_DATE_FORMATS = ["string", "123", "12.123", "22/04/2013", "04-22-2013", "2013/04/22", "2013-4-22T", "2013-04-22T9:00", "2013-04-22T09"]
end
