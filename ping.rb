require 'redis'
require 'net/ping'
require 'net/http'
require 'uri'
require 'cgi'
require 'pp'
require 'json'
require 'yaml'

hosts = YAML.load_file( 'hosts.yml' )["hosts"]
threads = []

@redis = Redis.new

hosts.each do |host|

  @redis.set( "pings-#{host}", "[]" )

  # The Pingers:
  threads << Thread.new {
    p = Net::Ping::TCP.new(host, 'http')
    while true do
      duration = -1
      success  = p.ping?
      duration = p.duration if success

      puts "#{Time.now} — #{host} :: Success: #{success}, Duration: #{duration}"

      start_time = Time.now
      pings = JSON.parse( @redis.get( "pings-#{host}" ) )
      this_ping = [Time.now.to_i, success, duration]
      pings.push( this_ping )
      pings.shift if pings.size > 1000
      @redis.set( "pings-#{host}", pings.to_json )

      # puts "    Duration: #{Time.now.to_f - start_time.to_f}"

      sleep 10
    end
  }
end

threads.each do |t|
  t.join
end
