require 'date'
require 'net/http/persistent'

class SEANoise

  class Error < RuntimeError; end

  def initialize date
    @date = date
    @date = Date.parse @date unless Date === @date

    @http = Net::HTTP::Persistent.new

    @root_uri = URI 'http://ems02.bksv.com/WebTrak/sea2/data/'
  end

  def start_handle
    date = @date.strftime '%Y-%m-%d%%2000:00:00'

    range_uri = @root_uri + "handle/#{date}"

    res = @http.request range_uri

    raise Error, res.body unless res.body =~ /<data/

    /startHandle="(?<start_handle>[^"]*)"/x =~ res.body
    /endHandle  ="(?<end_handle>  [^"]*)"/x =~ res.body

    # this API response is broken and may not include all of the data for the
    # start time in the start handle
    start_handle.to_i - 1
  end

  def extract_noise entries
    entries.select do |entry|
      entry.start_with? 'noise'
    end
  end

  def load_handle handle
    handle_uri = @root_uri + handle.to_s

    res = @http.request handle_uri

    /<data[^>]+>(?<body>.*?)<\/data>/m =~ res.body

    raise Error, res.body unless body

    body = body.split

    $stderr.puts "loaded #{body.length} for #{handle}"

    body
  end

  def load_handles
    handle = start_handle

    end_date = (@date + 1).strftime '%Y%m%d000000'

    loop do
      entries = load_handle handle

      yield entries

      if last = entries.last then
        _, date, = last.split ','

        break if date >= end_date
      end

      handle += 1
    end
  end

  def noise
    load_handles do |entries|
      noise = extract_noise entries

      noise.each do |entry|
        _, time, station, _, _, dBs = entry.split ','

        yield time, station, dBs
      end
    end
  end

  def write_noise
    file = @date.strftime '%Y-%m-%d-noise.csv'

    $stderr.puts "output: #{file}"

    mday = @date.strftime '%d'

    open file, 'w' do |io|
      noise do |time, station, dBs|
        /(.{4})(.{2})(.{2})(.{2})(.{2})(.{2})/ =~ time

        next unless $3 == mday

        io.puts "#{$1}-#{$2}-#{$3}T#{$4}:#{$5}:#{$6}-0700,#{station},#{dBs}"
      end
    end
  end

end

if ARGV.empty? then
  start = Date.parse '2013-06-10'

  first_monday =
    if start.monday? then
      start
    else
      start - start.wday + 8
    end

  first_monday.step Date.today, 7 do |date|
    SEANoise.new(date).write_noise
  end
else
  date = Date.parse ARGV.shift

  SEANoise.new(date).write_noise
end

