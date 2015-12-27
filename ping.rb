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
    while true do
      res = `sudo ping -c 1 #{host}`
      duration = /time=(\d+)/.match(res)[1].to_i rescue nil

      success = duration != nil

      puts "#{Time.now} — #{host} :: Success: #{success}, Duration: #{duration}"

      pings = JSON.parse( @redis.get( "pings-#{host}" ) )
      this_ping = [Time.now.to_i, success, duration]
      pings.push( this_ping )
      pings.shift if pings.size > 1000
      @redis.set( "pings-#{host}", pings.to_json )

      sleep 10
    end
  }
end

threads.each do |t|
  t.join
end
