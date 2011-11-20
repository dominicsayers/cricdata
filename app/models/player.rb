class Player
  include Mongoid::Document

  # Fields
  # Basic
  field :type_number,     :type => Integer
  field :player_ref,      :type => Integer
  field :name,            :type => String
  field :fullname,        :type => String
  field :dirty,           :type => Boolean

  # Stats
  field :matchcount,      :type => Integer

  # Batting
  field :innings,         :type => Integer
  field :completed,       :type => Integer
  field :runs,            :type => Integer
  field :minutes,         :type => Integer
  field :balls,           :type => Integer
  field :fours,           :type => Integer
  field :sixes,           :type => Integer
  field :bat_average,     :type => Float
  field :bat_strikerate,  :type => Float

  # Bowling
  field :overs,           :type => Integer
  field :oddballs,        :type => Integer
  field :overs_string,    :type => String
  field :maidens,         :type => Integer
  field :runsconceded,    :type => Integer
  field :wickets,         :type => Integer
  field :economy,         :type => Float
  field :bowl_average,    :type => Float
  field :bowl_strikerate, :type => Float

  # Fielding
  field :dismissals,      :type => Integer
  field :catches_total,   :type => Integer
  field :stumpings,       :type => Integer
  field :catches_wkt,     :type => Integer
  field :catches,         :type => Integer # Not as a wicketkeeper

  key :type_number, :player_ref
  index [ [:player_ref, Mongo::ASCENDING], [:type_number, Mongo::ASCENDING] ], unique: true
  index [ [:type_number, Mongo::ASCENDING], [:player_ref, Mongo::ASCENDING] ], unique: true

  # Validations

  # Scopes
  scope :dirty, where(dirty: true)
  scope :clean, where(dirty: false)
  scope :indeterminate, where(:dirty.exists => false)

  # Relationships
  has_many :performances

  # Helpers
  # Get history of fielding performances
  def self::get_fielding_statistics player
    player_id   = player._id
    player_ref  = player.player_ref

#-$\ = ' ' # debug

    # Get fielding data
    url = 'http://stats.espncricinfo.com/ci/engine/player/%s.json?class=%s;template=results;type=fielding;view=innings' % [player_ref, player.type_number]
    doc = get_data url

    # If player's basic details are incomplete then we can take
    # this opportunity to update them
    if player.name.nil?
      player.name = doc.xpath('//h1[@class="SubnavSitesection"]').first.content.split("/\n")[2].strip
      player.save
dp player.name, :cyan # debug
    end

    if player.fullname.nil?
      scripts = doc.xpath('//script')

      scripts.each do |script|
        /var omniPageName.+:(.+)";/i.match(script.content[0..100])

        unless $1.nil?
          player.fullname = $1
          player.save
dp $1, :cyan
          break
        end
      end
    end

    # Process fielding data
    nodeset = doc.xpath('//tr[@class="data1"]')

    if nodeset.length == 0
      return false # page not found
    else
      nodeset.each do |node|
        subnodes        = node.xpath('td')
#-dputs subnodes, :pink # debug
        # A player may have no performances in this category
        break unless subnodes.length > 1

        href            = '/ci/engine/match/'
        href_len        = href.length
        match_node      = subnodes[10].xpath("a[substring(@href,1,#{href_len})='#{href}']").first
#-dputs match_node.inspect, :pink # debug
        # There's a summary row that has no match ref
        if match_node.nil?
          # But we can get the number of matches played from this
          player.matchcount = subnodes[2].children.first.content
          player.save
        else
          href            = match_node.attributes['href'].value
          match_ref       = href[href_len..-1].split('.').first
#-dprint match_ref, :pink # debug
          matches         = Match.where(match_ref:match_ref)

          if matches.length == 0
            dputs "Match #{match_ref} not found", :red
          else
            match = matches.first
            inning_number   = subnodes[5].children.first.content
            inning          = match.innings.find_or_create_by inning_number: inning_number
            performance     = inning.performances.find_or_create_by player_id: player_id

            performance.dismissals    = subnodes[0].children.first.content
            performance.catches_total = subnodes[1].children.first.content
            performance.stumpings     = subnodes[2].children.first.content
            performance.catches_wkt   = subnodes[3].children.first.content
            performance.catches       = subnodes[4].children.first.content
            performance.save
          end
        end
      end
    end
  end

  # Update cumulative statistics from performance data
  def self::update_statistics player
    # Get fielding statistics
    self::get_fielding_statistics player

    # Process performance data
    player_id     = player._id
dputs "#{player.name} (#{player_id})", :white # debug

    performances  = Performance.where(player_id: player_id)

    # A player may have no performances, in which case we don't need them
    if performances.length == 0
      dputs 'No performances', :red
      player.destroy
      return false
    end

    # Batting stats
    innings         = 0
    completed       = 0
    runs            = 0
    minutes         = 0
    balls           = 0
    fours           = 0
    sixes           = 0
    bat_average     = 0.0
    bat_strikerate  = 0.0

    # Bowling stats
    overs           = 0
    overs_float     = 0.0
    overs_string    = ''
    ballsdelivered  = 0
    oddballs        = 0
    maidens         = 0
    runsconceded    = 0
    wickets         = 0
    bowl_average    = 0.0
    bowl_strikerate = 0.0
    economy         = 0.0

    # Fielding stats
    dismissals      = 0
    catches_total   = 0
    stumpings       = 0
    catches_wkt     = 0
    catches         = 0

    # Examine performances
    performances.each do |pf|
#-dp pf, :pink # debug
      # Batting stats
      unless pf.runs.nil?
        # Check fields
        pf.runs     = 0 unless pf.runs.is_a?(Numeric)
        pf.sixes    = 0 unless pf.sixes.is_a?(Numeric) # DJ Bravo, match 287853
        pf.notout   = pf[:howout].downcase.in?(['not out', 'retired hurt', 'absent hurt'])

        # Batting stats
        innings     += 1
        completed   += 1 unless pf.notout
        runs        += pf.runs    || 0
        minutes     += pf.minutes || 0
        balls       += pf.balls   || 0
        fours       += pf.fours   || 0
        sixes       += pf.sixes   || 0
#-dprint 'batting', :cyan # debug

        if completed > 0
          bat_average = runs.to_f / completed.to_f
          pf.average  = bat_average
        end

        if balls > 0
          bat_strikerate    = 100 * runs.to_f / balls.to_f
          pf.cum_strikerate = bat_strikerate
        end
      end

      unless pf.overs.nil?
#-dprint '-bowling', :cyan # debug
        # Bowling stats
        overs         += pf.overs
        oddballs      += pf.oddballs
        maidens       += pf.maidens
        runsconceded  += pf.runsconceded
        wickets       += pf.wickets

        # Assume 6-ball overs for now
        if pf.wickets > 0
          pf.strikerate = (pf.oddballs + 6 * pf.overs).to_f / pf.wickets.to_f
        end

        # Parse overs and odd balls into useful numbers
        ballsdelivered  = oddballs + (6 * overs)
        remainder       = ballsdelivered % 6
        overs_float     = ballsdelivered.to_f / 6
        overs_string    = overs_float.floor.to_s
        overs_string    += '.' + remainder.to_s unless remainder == 0

        if wickets > 0
          bowl_average      = runsconceded.to_f / wickets.to_f
          pf.average        = bowl_average
          bowl_strikerate   = ballsdelivered.to_f / wickets.to_f
          pf.cum_strikerate = bowl_strikerate
        end

        if overs_float > 0
          pf.cum_economy = runsconceded.to_f / overs_float
        end
      end

      unless pf.dismissals.nil?
#-dprint '-fielding', :cyan # debug
        # Fielding stats
        if pf.dismissals.is_a?(Numeric) # Can be 'TDNF' if player did not take field
          dismissals    += pf.dismissals
          catches_total += pf.catches_total
          stumpings     += pf.stumpings
          catches_wkt   += pf.catches_wkt
          catches       += pf.catches
        end
      end

#-dputs pf.inspect # debug
      pf.save
    end

#-dprint '-summary', :cyan # debug

    # Overall batting
    player.innings          = innings
    player.completed        = completed
    player.runs             = runs
    player.minutes          = minutes
    player.balls            = balls
    player.fours            = fours
    player.sixes            = sixes
    player.bat_average      = bat_average     if completed > 0
    player.bat_strikerate   = bat_strikerate  if balls > 0
#-dprint '-batting2', :cyan # debug

    # Rationalise overs and odd balls
    if ballsdelivered > 0
      overs     = (ballsdelivered / 6).floor.to_i
      oddballs  = ballsdelivered % 6
    end

    # Overall bowling
    player.overs            = overs
    player.oddballs         = oddballs
    player.overs_string     = overs_string
    player.maidens          = maidens
    player.runsconceded     = runsconceded
    player.wickets          = wickets
    player.bowl_average     = bowl_average                    if wickets > 0
    player.bowl_strikerate  = bowl_strikerate                 if wickets > 0
    player.economy          = runsconceded.to_f / overs_float if overs_float > 0
#-dprint '-bowling2', :cyan # debug

    # Overall fielding
    player.dismissals       = dismissals
    player.catches_total    = catches_total
    player.stumpings        = stumpings
    player.catches_wkt      = catches_wkt
    player.catches          = catches
#-dprint '-fielding2', :cyan # debug

    # Control
    player.dirty            = false
dputs player.inspect # debug
    player.save
  end

  def self::update_dirty_players
    # Recompile aggregate stats for players with
    # new performance information
    self::dirty.each do |player|
      update_statistics player
    end
  end

  def self::update player_ref
    player_list = self::where player_ref:player_ref

    player_list.each do |player|
dputs player.inspect # debug
      update_statistics player unless player.nil?
    end
  end
end
