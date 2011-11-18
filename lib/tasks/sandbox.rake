require 'net/http'
require "#{Rails.root}/app/helpers/console_log"
require "#{Rails.root}/app/helpers/fetch"

include ConsoleLog
include Fetch

desc "These are temporary, single-use tasks"

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

task :deflate_raw_matches => :environment do
    $\ = ' '

  RawMatch.all.each do |raw_match|
    zhtml = Zlib::Deflate.deflate(raw_match.html)
dp "#{raw_match._id} #{raw_match.html.length} #{zhtml.length}" # debug
  end
end

task :inflate_raw_matches => :environment do
  RawMatch.all.each do |raw_match|
    html = Zlib::Inflate.inflate(BSON.deserialize(raw_match.zhtml))
dp "#{raw_match._id} #{raw_match.zhtml.length} #{raw_match.html.length}" # debug
  end
end
