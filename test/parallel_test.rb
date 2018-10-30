require File.expand_path('../lib/all_tests/constants', __FILE__)

number_of_parallel_jobs = ARGV[0] ? ARGV[0] : 5
suite_type = ARGV[1] ? ARGV[1] : 'private'

puts "parent process starts at #{Time.now.strftime('%d/%m/%Y %H:%M:%S')}"

##############################################################################################################
#Initialize the necessary variables
total_tests = 0
queue = {}
pushed_count = 0
queue_count = 0
parent_process_id = $$
ENV['TEST_ENV_NAME'] = "parent_#{parent_process_id}"
ENV['REDIS_DB_NUMBER'] = "0"
tests_to_run = suite_type == 'private' ? ALL_TESTS_FALCON : ALL_TESTS_PUBLIC
##############################################################################################################

# Count the total number of test cases
tests_to_run.each do |file|
  tests = `cat #{file} | grep 'def test_' | wc -l`
  total_tests = total_tests + tests.match(/\d+/)[0].to_i
end

puts "splitting tests among #{number_of_parallel_jobs} jobs"
each_queue_count = total_tests / number_of_parallel_jobs.to_i
puts "Each job would process #{each_queue_count} tests approximately"


tests_to_run.each do |file|
  ### push based on tests count
  res = `cat #{file} | grep 'def test_' | wc -l`
  tests = res.match(/\d+/)[0].to_i
  queue[queue_count] ? queue[queue_count] << file : queue[queue_count] = [file]
  pushed_count = pushed_count + tests
  if pushed_count >= each_queue_count
    pushed_count = 0
    queue_count = queue_count + 1
  end
end

# Making necessary code changes compatible for parallel running
`sed -i -e "s/helpkit_test_rails3/helpkit_<%= ENV['TEST_ENV_NAME'] %>/g" config/database.yml`
`cat test/lib/helpdesk/initializers/redis.rb > lib/helpdesk/initializers/redis.rb`
`cat test/lib/helpdesk/initializers/memcached.rb > lib/helpdesk/initializers/memcached.rb`

# creating parent database
`bundle install`
`redis-server --port 6379 --daemonize yes`
`echo "create database helpkit_parent_#{parent_process_id}" | mysql -u root`
`bundle exec rake db:bootstrap RAILS_ENV=test`


def process_logger(message)
  puts "[Process:#{ENV['CHILD_PROCESS_ID']}] #{message}"
end

number_of_parallel_jobs.to_i.times do |i|
  Process.fork do
    child_process_id = $$
    # Set the nevessary environments for current process
    ENV['TEST_ENV_NAME'] = "child_#{child_process_id}"
    ENV['REDIS_DB_NUMBER'] = "#{i}"
    ENV['CHILD_PROCESS_ID'] = child_process_id.to_s

    process_logger "starts at #{Time.now.strftime('%d/%m/%Y %H:%M:%S')}"

    # Each process should not start at same time(bootkeeper erroring out)
    sleep (number_of_parallel_jobs.to_i - i + 1) * 10


    # create database for child and clone from parent
    `echo "create database helpkit_child_#{child_process_id}" | mysql -u root`
    `mysqldump -u root helpkit_parent_#{parent_process_id} | mysql -u root helpkit_child_#{child_process_id}`

    process_logger "Copied database from helpkit_parent_#{parent_process_id} to helpkit_child_#{child_process_id}"

    # create temp test suites for current process
    temp_suite = suite_type == 'public' ? "tempp_#{i}_public_api_test_suite.rb" : "tempp_#{i}.rb"
    `echo 'begin' > test/api/suites/#{temp_suite}`
    queue[i].each do |file|
      `echo '  require "./#{file}"' >> test/api/suites/#{temp_suite}`
    end
    `echo 'rescue Exception => e' >> test/api/suites/#{temp_suite}`
    `echo '  puts "Process exitted because of the exception"' >> test/api/suites/#{temp_suite}`
    `echo '  puts e.backtrace' >> test/api/suites/#{temp_suite}`
    `echo '  exit 1' >> test/api/suites/#{temp_suite}`
    `echo 'end' >> test/api/suites/#{temp_suite}`

    # run current test suite in current process
    `echo '' >  test/tmp_result_#{i}.log`
    `bundle exec ruby test/api/suites/#{temp_suite} >> test/tmp_result_#{i}.log`

    #clean-up
    `rm -f test/api/suites/#{temp_suite}`
    `echo "drop database helpkit_child_#{child_process_id}" | mysql -u root`

    process_logger "Dropped process database helpkit_child_#{child_process_id}"
    # print process message
    process_logger "ends at #{Time.now.strftime('%d/%m/%Y %H:%M:%S')}"
  end
end


processes = Process.waitall
`echo "drop database helpkit_parent_#{parent_process_id}" | mysql -u root`
p "All process ends for #{suite_type} at #{Time.now.strftime('%d/%m/%Y %H:%M:%S')}"


is_failed = false
number_of_parallel_jobs.to_i.times do |i|
  puts "============#{suite_type} result ======================"
  puts `cat test/tmp_result_#{i}.log`
  puts "============#{suite_type} result ends ======================"
  if `grep 'Process exitted because of the exception' test/tmp_result_#{i}.log`.length > 0
    is_failed = true
  end
  `rm -f test/tmp_result_#{i}.log`
end
exit 1 if is_failed
