require 'net/http'
require "#{Rails.root}/app/helpers/console_log"
require "#{Rails.root}/app/helpers/fetch"

include ConsoleLog
include Fetch

namespace :sandbox do
  task :career_span => :environment do
    $\ = ' '

    Player.where(:firstmatch.exists => false).each do |player|
      dprint player.name
    end
  end

  task :xfactor => :environment do
    Player.all.each do |player|
      next if player.bat_average.nil?
      next if player.bowl_average.nil?
dprint player.name
      player.xfactor = 5 + player.bat_average - player.bowl_average + (player.catches / player.matchcount)
dputs " #{player.xfactor}"
      player.save
    end
  end

  task :player_name => :environment do
    url     = 'http://stats.espncricinfo.com/ci/engine/player/%s.json?class=%s;template=results;type=fielding;view=innings' % ["52057", 1]
    doc     = get_data url

    name      = doc.xpath('//h1[@class="SubnavSitesection"]').first.content.split("/\n")[2].strip
  dp name

    scripts = doc.xpath('//script')

    scripts.each do |script|
      /var omniPageName.+:(.+)";/i.match(script.content[0..100])

      unless $1.nil?
  dp $1, :pink
        break
      end
    end
  end

  task :match_dates => :environment do
      $\ = ' '

    Match.all.each do |match|
      match_ref         = match.match_ref
  dprint match_ref # debug
      # Get match data
      raw_match       = RawMatch.find_or_create_by(match_ref: match_ref)

      if raw_match.html.blank?
        url             = 'http://www.espncricinfo.com/ci/engine/match/%s.json?view=scorecard' % match_ref
        raw_match.html  = get_response url
        raw_match.save
      end

      doc         = Nokogiri::HTML raw_match.html

      # Parse dates
      title = doc.xpath("//title").first.children.first.content
      /.+?,\s(\w{3})\s([0-9]{1,2})(?:,\s([0-9]+))*(?:\s*(?:-)*\s*(\w{3})*\s*([0-9]{1,2}),\s([0-9]+))*/i.match(title)

      m1 = $1
      d1 = $2
      y1 = $3
      m2 = $4
      d2 = $5
      y2 = $6

      y1 = y2 if y1.blank?
      m2 = m1 if m2.blank?
      d2 = d1 if d2.blank?
      y2 = y1 if y2.blank?

      m1n = Date::ABBR_MONTHNAMES.index(m1)
      m2n = Date::ABBR_MONTHNAMES.index(m2)

      date_start  = Date.new(y1.to_i, m1n, d1.to_i)
      date_end    = Date.new(y2.to_i, m2n, d2.to_i)
    end
  end

  task :deflate_raw_match => :environment do
      $\ = ' '

    raw_match = RawMatch.first
    zhtml = Zlib::Deflate.deflate(raw_match.html)
  dp zhtml, :pink # debug
  dputs "#{raw_match._id} #{raw_match.html.length} #{zhtml.length}" # debug
    raw_match.zhtml = BSON::Binary.new(zhtml)
  dp raw_match.zhtml, :cyan # debug
    raw_match.save
  end

  task :inflate_raw_match => :environment do
    raw_match = RawMatch.first
    zhtml = raw_match.zhtml.to_s
    html = Zlib::Inflate.inflate(zhtml)
  dputs "#{raw_match._id} #{raw_match.zhtml.length} #{raw_match.html.length}" # debug
  dputs html, :cyan
  end
end
