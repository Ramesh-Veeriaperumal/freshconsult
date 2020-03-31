require File.expand_path('../lib/all_tests/constants', __FILE__)

number_of_parallel_jobs = ARGV[0] ? ARGV[0] : 5
suite_type = ARGV[1] ? ARGV[1] : 'private'

##############################################################################################################
# Initialize the necessary variables
total_tests = 0
queue = {}
pushed_count = 0
queue_count = 1
tests_to_run = (suite_type.include? 'private') ? ALL_TESTS_FALCON : ALL_TESTS_PUBLIC
##############################################################################################################
test_files_with_rollback = tests_to_run.grep(/_new_test/)
test_files = (suite_type.include? '_w_rollback') ? test_files_with_rollback : (tests_to_run - test_files_with_rollback)

# Count the total number of test cases
test_files.each do |file|
  tests = `cat #{file} | grep 'def test_' | wc -l`
  total_tests = total_tests + tests.match(/\d+/)[0].to_i
end

if total_tests > 0
  puts "Total tests for suite #{suite_type} :: #{total_tests}"
  each_queue_count = total_tests / number_of_parallel_jobs.to_i
  puts "Each job would process #{each_queue_count} tests approximately"

  test_files.each do |file|
    res = `cat #{file} | grep 'def test_' | wc -l`
    tests = res.match(/\d+/)[0].to_i
    queue[queue_count] ? queue[queue_count] << file : queue[queue_count] = [file]
    pushed_count = pushed_count + tests
    if pushed_count >= each_queue_count
      pushed_count = 0
      queue_count = queue_count + 1
    end
  end

  puts queue.inspect
  puts "*" * 40

  (1..number_of_parallel_jobs.to_i).each do |i|
    temp_suite = "temp_#{suite_type}_#{i}_suite.rb"

    `echo 'begin' > test/api/suites/#{temp_suite}`
    queue[i].each do |file|
      `echo '  require "./#{file}"' >> test/api/suites/#{temp_suite}`
    end
    `echo 'rescue Exception => e' >> test/api/suites/#{temp_suite}`
    `echo '  puts "Process exited because of the exception"' >> test/api/suites/#{temp_suite}`
    `echo '  puts e.inspect' >> test/api/suites/#{temp_suite}`
    `echo '  puts e.backtrace' >> test/api/suites/#{temp_suite}`
    `echo '  exit 1' >> test/api/suites/#{temp_suite}`
    `echo 'end' >> test/api/suites/#{temp_suite}`

    `echo '' >  test_log/#{suite_type}_#{i}.log`
  end
else
  puts "No tests present for suite #{suite_type}"
end