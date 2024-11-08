# frozen_string_literal: true

require 'net/http'
require 'mongo'
require Rails.root.join('app/utilities/console_log').to_s
require Rails.root.join('app/utilities/fetch').to_s

include ConsoleLog
include Fetch
include Mongo

namespace :sandbox do
  desc 'Fetch & parse particular match'
  task parse_match: :environment do
    match_ref = ENV.fetch('MATCH_REF', nil)
    dputs "Parsing match #{match_ref}..."
    Match.parse match_ref
    dputs 'done.'
  end

  task fixup_performances: :environment do
    $\ = ' '

    Performance.where(:type_number.exists => false).find_each do |pf|
      dprint pf.match_type_player_id
      dprint pf.inning_id

      mtp = MatchTypePlayer.find pf.match_type_player_id
      dprint mtp.fullname

      match_id = pf.inning_id.split('-').first
      match = Match.find match_id
      dprint match_id
      dprint match.date_start

      type_number = pf.match_type_player_id.split('-').first
      dprint type_number

      pf.name         = mtp.fullname
      pf.date_start   = match.date_start
      pf.type_number  = type_number
      pf.save
      dputs ' '
    end
  end

  task list_performances_by_country: :environment do
    $\ = ' '

    # Using mongo gem directly because of the size of the result set
    if %w[test production].include?(ENV['RAILS_ENV'])
      hostname	= 'burdett.moo.li'
      db_name		= 'cricdata'
    else
      hostname	= 'localhost'
      db_name		= 'cricdata_development'
    end

    db 			= Connection.new(hostname).db db_name
    pfs			= db.collection('performances')
    dputs db.connection.host
    dputs db_name

    #		pfs.find(:runs => {'$ne' => nil}).sort( [ [:type_number, Mongo::ASCENDING], [:date_start, Mongo::ASCENDING], [:runs, Mongo::ASCENDING] ] ).each do |pf|
    pfs.find.each do |pf|
      dprint pf['type_number']
      dprint pf['inning_id']
      dprint pf['name']

      Inning.find pf['inning_id']

      dputs ' '
    end
  end

  task initials: :environment do
    $\ = ' '

    Player.where(:name.exists => true).find_each do |player|
      initials = player.slug.split('-').first
      forename = player.fullname.split.first.downcase

      next unless initials != forename

      l = initials.length
      next unless l > 4

      dprint player.slug
      dprint player.name
      dprint initials, :white
      dprint forename, :cyan
      dputs l, :red
    end
  end

  task scores: :environment do
    $\ = ' '

    # Using mongo gem directly because of the size of the result set
    if %w[test production].include?(ENV['RAILS_ENV'])
      hostname	= 'burdett.moo.li'
      db_name		= 'cricdata'
    else
      hostname	= 'localhost'
      db_name		= 'cricdata_development'
    end
    db 			= Connection.new(hostname).db db_name
    pfs			= db.collection('performances')
    dputs db.connection.host
    dputs db_name

    pfs.find(runs: { '$ne' => nil }).sort([[:type_number, Mongo::ASCENDING], [:date_start, Mongo::ASCENDING],
                                           [:runs, Mongo::ASCENDING]]).each do |pf|
      dprint pf['type_number']
      dprint pf['date_start']
      dprint pf['runs']
      dprint pf['name']

      #			IndividualScore.register pf['type_number'], pf['runs'], pf['date_start'], pf['name']
      dputs ' '
    end
  end

  task env: :environment do
    dputs ENV.fetch('RAILS_ENV', nil)

    db_name = %w[test production].include?(ENV['RAILS_ENV']) ? 'cricdata' : 'cricdata_development'
    dputs db_name
  end

  task match_age: :environment do
    $\ = ' '

    Match.find_each do |match|
      dprint match.serial
      dprint match.date_end
      dprint 1.week.ago.to_date
      dputs match.date_end < 1.week.ago.to_date ? 'Old match' : 'Recent match'
    end
  end

  task update_players_no_fielding: :environment do
    $\ = ' '

    # Mark all players dirty
    MatchTypePlayer.update_all(dirty: true)

    # Update players without refetching fielding data
    MatchTypePlayer.dirty.each do |mtp|
      MatchTypePlayer.update_statistics mtp, do_fielding: false
    end
  end

  task new_stats: :environment do
    $\ = ' '

    Performance.destroy_all

    Match.find_each do |match|
      match_ref = match.match_ref
      dputs match_ref, :white
      # Get match data
      raw_match = RawMatch.find_or_create_by(match_ref: match_ref)

      if raw_match.zhtml.blank?
        url             = 'http://www.espncricinfo.com/ci/engine/match/%s.json?view=scorecard' % match_ref
        raw_match.zhtml = BSON::Binary.new(Zlib::Deflate.deflate(get_response(url)))
        raw_match.save
      end

      doc = Nokogiri::HTML(Zlib::Inflate.inflate(raw_match.zhtml.to_s))

      # Check which columns are available
      # Innings header
      # We don't know which batting stats were recorded for this innings
      inning_nodeset  = doc.xpath("//tr[@class='inningsHead']")
      inning_number   = 1
      borb            = :batting
      stats_template  = {}

      inning_nodeset.each do |inning_node|
        inning_header_nodeset = inning_node.xpath('td/b')
        stats_template[inning_number] = { batting: [], bowling: [] } unless stats_template.key? inning_number
        # -dputs borb
        # -dputs "Innings #{inning_number}"

        inning_header_nodeset.each do |inning_header_node|
          # Gather the column headings: R M B 4s 6s SR etc.
          # -dp inning_header_node, :pink
          # -dputs inning_header_node.children.length, :pink
          text = inning_header_node.children.empty? ? :Extras : inning_header_node.children.first.text
          text = :Extras if text.nil?
          stats_template[inning_number][borb] << text.to_sym
        end
        # -dp stats_template[inning_number][borb]

        if borb == :bowling
          inning_number += 1
          borb = :batting
        else
          borb = :bowling
        end
      end
      # -dp stats_template, :cyan

      # Innings
      inning_nodeset  = doc.xpath("//tr[@class='inningsRow']/td")
      inning_number   = 1
      borb            = :batting
      stats           = {}
      pf              = {}
      stats_counter   = 0

      inning_nodeset.each do |inning_node|
        classattr     = inning_node.attributes['class']
        classname     = classattr.nil? ? '' : classattr.value
        firstchild    = inning_node.children.first
        text          = !firstchild.nil? && firstchild.text? ? firstchild.content.strip : ''

        stats[inning_number] = { batting: [], bowling: [] } unless stats.key? inning_number

        case classname.to_sym
        when :playerName
          stats[inning_number][borb] << pf unless pf == {} # save current performance hash

          # This is the next player, so start a new performance hash
          player_node   = firstchild
          href          = '/ci/content/player/'
          href_len      = href.length
          href          = player_node.attributes['href'].value
          pf            = { name: player_node.children.first.content, ref: href[href_len..].split('.').first }
          stats_counter = 0
        when :inningsDetails
          stats[inning_number][borb] << pf unless pf == {} # save current performance hash

          # Innings summary, so start a new performance hash
          pf            = { name: text, ref: 0 }
          stats_counter = 0
        when :battingDismissal
          if borb == :bowling
            # When we go from bowling performances to batting, that's the start of the next innings
            inning_number += 1
            borb          = :batting
            stats_counter = 0
          end

          pf[:howout] = text
        when :battingRuns, :battingDetails
          key = stats_template[inning_number][borb][stats_counter]
          # -dprint "#{stats_counter} #{key}", :pink
          stats_counter += 1
          pf[key] = text
        when :bowlingDetails
          if borb == :batting
            borb          = :bowling
            stats_counter = 0
          end

          key = stats_template[inning_number][borb][stats_counter]
          # -dprint "#{stats_counter} #{key}", :pink
          stats_counter += 1
          pf[key] = text
        end
      end

      stats[inning_number][borb] << pf unless pf == {} # save current performance hash

      # Now we have the stats gathered into a hash, we can parse out the
      # players' performmances
      (1..4).each do |inning_number|
        break unless stats.key? inning_number

        inning      = match.innings.find_or_create_by inning_number: inning_number
        type_number = match.match_type.type_number

        # Batting
        stats[inning_number][:batting].each do |p|
          dp p, :white
          if (p[:ref]).zero?
            # Record innings analysis
            if p[:name].downcase == 'extras'
              inning.extras          = p[:runs]
              inning.extras_analysis = p[:howout]
            else
              inning.summary         = p[:howout]
            end
          else
            # Make sure player exists
            mtp        = MatchTypePlayer.find_or_create_by type_number: type_number, player_ref: p[:ref]
            mtp.name   = p[:name]
            mtp.dirty  = true
            mtp.save

            performance = inning.performances.find_or_create_by match_type_player_id: mtp._id

            # Record batting analysis
            performance.runs          = p[:R]
            performance.minutes       = p[:M]
            performance.balls         = p[:B]
            performance.fours         = p[:'4s']
            performance.sixes         = p[:'6s']
            performance.strikerate    = p[:SR]
            performance.howout        = p[:howout]
            performance.notout        = p[:howout].downcase.in?(['not out', 'retired hurt', 'absent hurt'])

            performance.save
            dp performance
          end

          inning.save
        end

        stats[inning_number][:bowling].each do |p|
          dp p, :white

          # Record bowling analysis
          overs = p[:O]
          o_and_b = overs.split('.')

          if o_and_b.length == 2
            overs = o_and_b.first
            balls = o_and_b.last
          else
            balls = 0
          end

          # Make sure player exists
          mtp        = MatchTypePlayer.find_or_create_by type_number: type_number, player_ref: p[:ref]
          mtp.name   = p[:name]
          mtp.dirty  = true
          mtp.save

          performance = inning.performances.find_or_create_by match_type_player_id: mtp._id

          performance.overs         = overs
          performance.oddballs      = balls
          performance.maidens       = p[:M]
          performance.runsconceded  = p[:R]
          performance.wickets       = p[:W]
          performance.economy       = p[:Econ]
          performance.extras        = p[:Extras]

          performance.save
          dp performance
        end
      end
    end
  end

  task deflate_raw_match: :environment do
    $\ = ' '

    raw_match = RawMatch.first
    zhtml = Zlib::Deflate.deflate(raw_match.html)
    # -dp zhtml, :pink # debug
    dputs "#{raw_match._id} #{raw_match.html.length} #{zhtml.length}" # debug
    raw_match.zhtml = BSON::Binary.new(zhtml)
    # -dp raw_match.zhtml, :cyan # debug
    raw_match.save
  end

  task reparse_T20Is: :environment do
    Match.where(match_type_id: '3').find_each do |match|
      match_ref = match.match_ref
      dputs match_ref, :white
      Match.parse match_ref
    end
  end

  task fixup_performances: :environment do
    $\ = ' '

    Performance.where(:player_id.exists => true).limit(65_000).each do |pf|
      #      pf.match_type_player_id = pf.player_id
      pf.unset(:player_id)
      pf.save
      dprint pf.match_type_player_id
    end
    dputs "\r\ndone"
  end

  task player_friendly_id: :environment do
    $\ = ' '

    Player.destroy_all

    MatchTypePlayer.find_each do |mtp|
      mtp.unset(:player_id)
      mtp.unset(:player_ids)

      unless mtp.name.nil?
        dprint mtp.name, :white
        slug = mtp.name.parameterize
        dprint slug, :cyan

        player = Player.find_or_create_by slug: slug # slug is unique (fingers crossed)

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

        player = Player.find_or_create_by slug: slug

        player.add_to_set :player_refs, mtp.player_ref
        player.add_to_set :match_type_player_ids, mtp._id
        dp player.player_refs
        player.save

        # Do all components of name too
        nameparts = mtp.fullname.split

        nameparts.each do |subslug|
          slug = subslug.parameterize
          dprint slug, :cyan

          player = Player.find_or_create_by slug: slug

          player.add_to_set :player_refs, mtp.player_ref

          dp player.player_refs
          player.save
        end
      end

      mtp.save
    end
  end

  task career_span: :environment do
    $\ = ' '

    zeroday = Match.min(:date_start).to_date
    dputs zeroday

    MatchTypePlayer.find_each do |mtp|
      dprint mtp.name, :white

      debut     = Time.zone.today.to_date
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

  task xfactor: :environment do
    MatchTypePlayer.find_each do |mtp|
      next if mtp.bat_average.nil?
      next if mtp.bowl_average.nil?

      dprint mtp.name
      mtp.xfactor = 5 + mtp.bat_average - mtp.bowl_average + (mtp.catches / mtp.matchcount)
      dputs " #{mtp.xfactor}"
      mtp.save
    end
  end

  task mtp_name: :environment do
    url = format(
      'https://stats.espncricinfo.com/ci/engine/player/%s.json?class=%s;template=results;type=fielding;view=innings', '52057', 1
    )
    doc = get_data url

    name = doc.xpath('//h1[@class="SubnavSitesection"]').first.content.split("/\n")[2].strip
    dp name

    scripts = doc.xpath('//script')

    scripts.each do |script|
      /var omniPageName.+:(.+)";/i.match(script.content[0..100])

      unless Regexp.last_match(1).nil?
        dp Regexp.last_match(1), :pink
        break
      end
    end
  end

  task match_dates: :environment do
    $\ = ' '

    Match.find_each do |match|
      match_ref = match.match_ref
      dprint match_ref
      # Get match data
      raw_match = RawMatch.find_or_create_by(match_ref: match_ref)

      if raw_match.html.blank?
        url             = 'http://www.espncricinfo.com/ci/engine/match/%s.json?view=scorecard' % match_ref
        raw_match.html  = get_response url
        raw_match.save
      end

      doc = Nokogiri::HTML raw_match.html

      # Parse dates
      title = doc.xpath('//title').first.children.first.content
      /.+?,\s(\w{3})\s([0-9]{1,2})(?:,\s([0-9]+))*(?:\s*(?:-)*\s*(\w{3})*\s*([0-9]{1,2}),\s([0-9]+))*/i.match(title)

      m1 = Regexp.last_match(1)
      d1 = Regexp.last_match(2)
      y1 = Regexp.last_match(3)
      m2 = Regexp.last_match(4)
      d2 = Regexp.last_match(5)
      y2 = Regexp.last_match(6)

      y1 = y2 if y1.blank?
      m2 = m1 if m2.blank?
      d2 = d1 if d2.blank?
      y2 = y1 if y2.blank?

      m1n = Date::ABBR_MONTHNAMES.index(m1)
      m2n = Date::ABBR_MONTHNAMES.index(m2)

      Date.new(y1.to_i, m1n, d1.to_i)
      Date.new(y2.to_i, m2n, d2.to_i)
    end
  end

  task deflate_raw_match: :environment do
    $\ = ' '

    raw_match = RawMatch.first
    zhtml = Zlib::Deflate.deflate(raw_match.html)
    # -dp zhtml, :pink # debug
    # -dputs "#{raw_match._id} #{raw_match.html.length} #{zhtml.length}" # debug
    raw_match.zhtml = BSON::Binary.new(zhtml)
    # -dp raw_match.zhtml, :cyan # debug
    raw_match.save
  end

  task inflate_raw_match: :environment do
    raw_match = RawMatch.first
    zhtml = raw_match.zhtml.to_s
    html = Zlib::Inflate.inflate(zhtml)
    # -dputs "#{raw_match._id} #{raw_match.zhtml.length} #{raw_match.html.length}" # debug
    dputs html, :cyan
  end
end
