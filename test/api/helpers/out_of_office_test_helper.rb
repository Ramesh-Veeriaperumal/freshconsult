module OutOfOfficeTestHelper
  def sample_index
    {
      'data' => [
        {
          'id': 1,
          'start_time': '2018-01-08T12:00:00Z',
          'end_time': '2019-01-08T12:01:00Z'
        }
      ]
    }
  end

  def sample_show
    {
      'id': 1,
      'start_time': '2018-01-08T12:00:00Z',
      'end_time': '2019-01-08T12:01:00Z'
    }
  end
end
