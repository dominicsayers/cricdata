require 'net/http'
require "#{Rails.root}/app/helpers/console_log"
require "#{Rails.root}/app/helpers/fetch"

include ConsoleLog
include Fetch

namespace :sandbox do
  task :minutes => :environment do
      $\ = ' '

    Match.all.each do |match|
      match_ref         = match.match_ref
  dputs match_ref, :white # debug
      # Get match data
      raw_match       = RawMatch.find_or_create_by(match_ref: match_ref)

      if raw_match.zhtml.blank?
        url             = 'http://www.espncricinfo.com/ci/engine/match/%s.json?view=scorecard' % match_ref
        raw_match.zhtml = BSON::Binary.new(Zlib::Deflate.deflate(get_response(url)))
        raw_match.save
      end

      doc = Nokogiri::HTML(Zlib::Inflate.inflate(raw_match.zhtml.to_s))

      # Check batting columns
      # Innings header
      # We don't know which batting stats were recorded for this innings
      inning_nodeset  = doc.xpath("//tr[@class='inningsHead']")
      inning          = 1
      borb            = :batting
      stats_template  = {}

      inning_nodeset.each do |inning_node|
        inning_header_nodeset = inning_node.xpath('td/b')
        stats_template[inning] = {:batting => [], :bowling => []} unless stats_template.has_key? inning
#-dputs borb
#-dputs "Innings #{inning}"

        inning_header_nodeset.each do |inning_header_node|
dp inning_header_node, :pink
dputs inning_header_node.children.length, :pink
          break if inning_header_node.children.length == 0
          text = inning_header_node.children.first.text
          stats_template[inning][borb] << text.to_sym
        end
#-dp stats_template[inning][borb]

        if borb == :bowling
          inning  += 1
          borb    = :batting
        else
          borb    = :bowling
        end
      end
dp stats_template, :cyan

      # Innings
      inning_nodeset  = doc.xpath("//tr[@class='inningsRow']/td")
      inning          = 1
      borb            = :batting
      stats           = {}
      pf              = {}
      stats_counter   = 0

      inning_nodeset.each do |inning_node|
        classattr     = inning_node.attributes['class']
        classname     = classattr.nil? ? '' : classattr.value
        firstchild    = inning_node.children.first
        text          = !firstchild.nil? && firstchild.text? ? firstchild.content.strip : ''
        stats[inning] = {:batting => [], :bowling => []} unless stats.has_key? inning

        case classname.to_sym
        when :playerName
          stats[inning][borb] << pf unless pf == {} # save current performance hash

          # This is the next player, so start a new performance hash
          player_node   = firstchild
          href          = '/ci/content/player/'
          href_len      = href.length
          href          = player_node.attributes['href'].value
          pf            = {name:player_node.children.first.content, ref:href[href_len..-1].split('.').first}
          stats_counter = 0
        when :inningsDetails
          stats[inning][borb] << pf unless pf == {} # save current performance hash

          # Innings summary, so start a new performance hash
          pf            = {name:text, ref:0}
          stats_counter = 0
        when :battingDismissal
          if borb == :bowling
            # When we go from bowling performances to batting, that's the start of the next innings
            inning        += 1
            borb          = :batting
            stats_counter = 0
          end

          pf[:howout]     = text
        when :battingRuns, :battingDetails
          key             = stats_template[inning][borb][stats_counter]
dprint "#{stats_counter} #{key}", :pink
          stats_counter   += 1
          pf[key]         = text
        when :bowlingDetails
          if borb == :batting
            borb          = :bowling
            stats_counter = 0
          end

          key             = stats_template[inning][borb][stats_counter]
dprint "#{stats_counter} #{key}", :pink
          stats_counter   += 1
          pf[key]         = text
        end
      end

      stats[inning][borb] << pf unless pf == {} # save current performance hash
dpp stats
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

  task :reparse_T20Is => :environment do
    Match.where(match_type_id:"3").each do |match|
      match_ref = match.match_ref
      dputs match_ref, :white
      Match.parse match_ref
    end
  end

  task :fixup_performances => :environment do
$\= ' '

    Performance.where(:player_id.exists => true).limit(65000).each do |pf|
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
