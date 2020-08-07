require 'zip'
require 'tempfile'

RETRY_COUNT = 3
S3_FILE_PATH = "blacklisted_ips/processed_bannedips.csv"

namespace :blacklisted_ips do
  desc "This task will download blacklisted_ips file and update the redis" 
  task :download_ips => :environment do
    include Helpdesk::S3::Util
    start = Time.now
    blacklisted_ips = get_response(URI("http://www.stopforumspam.com/downloads/bannedips.zip")) 
    aws_ip_range = get_response(URI("https://ip-ranges.amazonaws.com/ip-ranges.json"))
    if aws_ip_range && blacklisted_ips
      @count = construct_ip_tree(aws_ip_range)
      updated_ips = get_from_s3
      new_ips = extract_blocked_ips(blacklisted_ips)
      ip_size = new_ips.size - 1
      @ip_counter = - 1
      ip = fetch_next_ip(new_ips) if @ip_counter < ip_size
      updated_ips.each do |updated_ip|
        if updated_ip == ip
          ip = fetch_next_ip(new_ips) if @ip_counter < ip_size
        else 
          while (ip < updated_ip && @ip_counter < ip_size )
            redis_operation(ip, true) unless check_aws_ip(ip)
            ip = fetch_next_ip(new_ips) 
          end
          if ip == updated_ip 
            ip = fetch_next_ip(new_ips) if @ip_counter < ip_size
          else
            redis_operation(updated_ip, false) unless check_aws_ip(updated_ip)
          end
        end
      end
      while @ip_counter <= ip_size
        redis_operation(ip, true) unless check_aws_ip(ip)
        ip = fetch_next_ip(new_ips) 
      end
    end
    elapsed = (Time.now - start).round(2)
    puts "the time taken is #{elapsed}"
  end

  desc "This task will remove all the blacklisted ips from redis" 
  task :remove_ips => :environment do
    start = Time.now
    blacklisted_ips = get_response(URI("http://www.stopforumspam.com/downloads/bannedips.zip")) 
    if blacklisted_ips
      new_ips = extract_blocked_ips(blacklisted_ips)      
      new_ips.each do | ip |
        redis_operation(ip, false) 
      end
    end
    elapsed = (Time.now - start).round(2)
    puts "the time taken is #{elapsed}"
  end
end

def fetch_next_ip(new_ips)
  @ip_counter += 1 
  new_ips[@ip_counter]
end


def redis_operation(ip, flag)
  hash_key = blacklist_hash(ip)
  flag ? $rate_limit.perform_redis_op("hset",hash_key,ip,1) :  $rate_limit.perform_redis_op("hdel",hash_key,ip)
end

def extract_blocked_ips(ips)
  zip_file = Tempfile.new('blacklisted_ips.zip',:encoding => 'ascii-8bit')
  zip_file.write(ips) 
  ip_zip=Zip::File.open(zip_file)
  ip_zip.each do |file|                                                     
    ips = file.get_input_stream.read
  end  
  replace_file_in_s3(ips)
  zip_file.unlink         
  ips=ips.split(",")
end


def construct_ip_tree(ip_range)
  @ip_list = []
  result=JSON.parse(ip_range)
  result["prefixes"].each do | res |
    ip_range=IPAddr.new(res["ip_prefix"]).to_range
    @ip_list << [ip_range.first.to_i,ip_range.last.to_i]
  end
  @ip_list.length
end


def get_response(uri)
  RETRY_COUNT.times do 
    response = Net::HTTP.get_response(uri) 
    return response.body if response.is_a?(Net::HTTPSuccess)
  end
  deliver_error_mailer("Error in getting the response for uri #{uri}")
end

def blacklist_hash(ip)
  "blacklist"+(ip.gsub(".","").to_i%10_000).to_s
end

def get_from_s3
  AwsWrapper::S3.read(S3_CONFIG[:bucket], S3_FILE_PATH).split(',')
end

def replace_file_in_s3(ips)
  AwsWrapper::S3.put(S3_CONFIG[:bucket], S3_FILE_PATH, ips, server_side_encryption: 'AES256') # PRE-RAILS: Needs to be checked
end

def check_aws_ip(ip)
  ip = IPAddr.new(ip).to_i
  binary_search(ip)
end

def binary_search(ip)
  haystack = @ip_list
  high = @count - 1
  low = 0
  while (high >= low) do
    probe = (high + low) / 2
    row = haystack[probe]
    if (row[0] > ip)
      high = probe - 1
    elsif(row[1] < ip)
      low = probe + 1
    else
      return row
    end
  end
  return nil
end

def deliver_error_mailer(e)
  FreshdeskErrorsMailer.deliver_error_email(nil, nil, nil,
    {
      :subject => "Error in blacklisted ips rake",
      :recipients => Rails.env.production? ? Helpdesk::EMAIL[:production_dev_ops_email] : "dev-ops@freshpo.com",
      :additional_info  => { :error => e }
    }
  )
  return false
end
