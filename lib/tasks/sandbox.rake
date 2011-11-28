require 'net/http'
require "#{Rails.root}/app/helpers/console_log"
require "#{Rails.root}/app/helpers/fetch"

include ConsoleLog
include Fetch

namespace :sandbox do
  task :reparse_T20Is => :environment do
    Match.where(match_type_id:"3").each do |match|
      match_ref = match.match_ref
      dputs match_ref, :white
      Match.parse match_ref
    end
  end

  task :fixup_performances => :environment do
$\= ' '

    Performance.all.each do |pf|
#      pf.match_type_player_id = pf.player_id
      pf.unset(:player_id)
      pf.save
dprint pf.match_type_player_id
    end
dputs "\r\ndone"
  end

  task :player_friendly_id => :environment do
    $\ = ' '

    Player.destroy_all

    MatchTypePlayer.all.each do |mtp|
      mtp.unset(:player_id)
      mtp.unset(:player_ids)
    end

    MatchTypePlayer.all.each do |mtp|
      unless mtp.name.nil?
        dprint mtp.name, :white
        slug = mtp.name.parameterize
        dprint slug, :cyan

        player = Player.find_or_create_by slug:slug # slug is unique (fingers crossed)

        player.add_to_set :player_refs, mtp.player_ref
        player.save
        dp player.player_refs
        mtp.player = player
      end

      if mtp.fullname.nil?
        dputs 'No full name', :red
      else
        slug = mtp.fullname.parameterize
        dprint slug, :cyan

        player = Player.find_or_create_by slug:slug

        player.add_to_set :player_refs, mtp.player_ref
        player.add_to_set :match_type_player_ids, mtp._id
        dp player.player_refs
        player.save

        # Do all components of name too
        nameparts = mtp.fullname.split(' ')

        nameparts.each do |subslug|
          slug = subslug.parameterize
          dprint slug, :cyan

          player = Player.find_or_create_by slug:slug

          player.add_to_set :player_refs, mtp.player_ref

          dp player.player_refs
          player.save
        end
      end

      mtp.save
    end
  end

  task :career_span => :environment do
    $\ = ' '

    zeroday = Match.min(:date_start).to_date
    dputs zeroday

    MatchTypePlayer.all.each do |mtp|
      dprint mtp.name, :white

      debut     = Date.today.to_date
      swansong  = zeroday

      mtp.performances.each do |pf|
        match = pf.inning.match
        date_start  = match.date_start.to_date
        date_end    = match.date_end.to_date

        debut       = date_start  if date_start < debut
        swansong    = date_end    if date_end > swansong
      end

      dprint debut
      dputs swansong

      mtp.firstmatch = debut
      mtp.lastmatch  = swansong
      mtp.save
    end
  end

  task :xfactor => :environment do
    MatchTypePlayer.all.each do |mtp|
      next if mtp.bat_average.nil?
      next if mtp.bowl_average.nil?
dprint mtp.name
      mtp.xfactor = 5 + mtp.bat_average - mtp.bowl_average + (mtp.catches / mtp.matchcount)
dputs " #{mtp.xfactor}"
      mtp.save
    end
  end

  task :mtp_name => :environment do
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
