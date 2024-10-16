class MatchTypePlayer
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
  field :firstmatch,      :type => Date
  field :lastmatch,       :type => Date
  field :xfactor,         :type => Float

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

#  key :type_number, :player_ref
  index({ player_ref:1, type_number:1 }, { unique:true })
  index({ type_number:1, player_ref:1 }, { unique:true })
  index({ type_number:1, xfactor:-1 })

  # Validations

  # Scopes
  scope :dirty, ->{ where(dirty: true) }
  scope :clean, ->{ where(dirty: false) }
  scope :indeterminate, ->{ where(:dirty.exists => false) }
  scope :xfactory, ->{ where(:xfactor.ne => nil).desc(:xfactor) }

  # Relationships
  belongs_to :player
  has_many :performances

  # Helpers
  #----------------------------------------------------------------------------
  # Get player data (including fielding performances)
  def get_player_data
    # Get fielding data
    url = 'http://stats.espncricinfo.com/ci/engine/player/%s.json?class=%s;template=results;type=fielding;view=innings' % [self.player_ref, self.type_number]
    doc = get_data url

    return doc
  end

  # Update names
  def update_names doc=nil
    if self.name.blank?
      doc = self.get_player_data if doc.blank?
      self.name  = doc.xpath('//h1[@class="SubnavSitesection"]').first.content.split("/\n")[2].strip
      self.save
    end

    if self.fullname.blank?
      doc = self.get_player_data if doc.blank?
      scripts = doc.xpath('//script')

      scripts.each do |script|
        /var omniPageName.+:(.+)";/i.match(script.content[0..100])

        unless $1.nil?
          self.fullname  = $1
          self.save
          break
        end
      end
    end

    player_ref = self.player_ref

    # Update Player document
    # Scorecard name (master document)
    slug    = self.name.parameterize
    player  = Player.find_or_create_by! slug:slug # slug is unique (fingers crossed)
    player.master_ref = player_ref
    player.name       = self.name
    player.fullname   = self.fullname
    player.add_to_set(player_refs: player_ref)
    player.add_to_set(match_type_player_ids: self._id)
dp player, :pink # debug
    player.save!

    self.player = player
    self.save

    # Full name
    slug    = self.fullname.parameterize
    player  = Player.find_or_create_by! slug:slug
    player.add_to_set(player_refs: player_ref)
    player.add_to_set(match_type_player_ids: self._id)
    player.save!

    # Name parts
    nameparts = self.fullname.split(' ')

    nameparts.each do |subslug|
      slug    = subslug.parameterize
      player  = Player.find_or_create_by! slug:slug
      player.add_to_set(player_refs: player_ref)
      player.save!
    end
  end

  # Get history of fielding performances
  def self::get_fielding_statistics mtp
    match_type_player_id  = mtp._id
    player_ref            = mtp.player_ref

$\ = ' ' # debug
dputs player_ref, :cyan # debug

    # Get fielding data
    doc = mtp.get_player_data

    # If player's basic details are incomplete then we can take
    # this opportunity to update them
    mtp.update_names doc

    # Process fielding data
    nodeset = doc.xpath('//tr[@class="data1"]')
    lastmatch = 0

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
          mtp.matchcount = subnodes[2].children.first.content
          mtp.save
        else
          href            = match_node.attributes['href'].value
          match_ref       = href[href_len..-1].split('.').first
#-dprint match_ref, :pink # debug
          matches         = Match.where(match_ref:match_ref)
#-dprint matches.length, :pink # debug

          if matches.length == 0
            dputs "Match #{match_ref} not found", :red
            exit
          else
            match = matches.first
#-dp match, :cyan # debug

            # Is this the player's debut match?
            if mtp.firstmatch.nil?
              mtp.firstmatch = match.date_start
              mtp.save
            end

            lastmatch       = match.date_end
            dismissals      = subnodes[0].children.first.content

            if /\d+/.match(dismissals) # Ignore TDNF, DNF etc.
              inning_number   = subnodes[5].children.first.content
              inning          = match.innings.find_or_create_by inning_number: inning_number
              performance     = inning.performances.find_or_create_by match_type_player_id: match_type_player_id

              performance.dismissals    = dismissals
              performance.catches_total = subnodes[1].children.first.content
              performance.stumpings     = subnodes[2].children.first.content
              performance.catches_wkt   = subnodes[3].children.first.content
              performance.catches       = subnodes[4].children.first.content
              performance.save
            else
              dputs dismissals, :cyan
            end
          end
        end
      end
    end

    unless lastmatch == 0
      mtp.lastmatch = lastmatch
      mtp.save
    end
  end

  #----------------------------------------------------------------------------
  # Update X-factor from batting, bowling & fielding stats
  def self::update_xfactor mtp
    if mtp.matchcount.nil? || mtp.bat_average.nil? || mtp.bowl_average.nil?
dprint 'No average' # debug
      mtp.unset(:xfactor)
    else
      case mtp.type_number
      when MatchType::TEST
dprint 'Test' # debug
        if mtp.runs < 500 || mtp.bat_average < 30 || mtp.wickets < 50 || mtp.bowl_average > 35 || mtp.lastmatch < Date.new(1945)
          # Doesn't qualify
          mtp.unset(:xfactor)
        else
          # Test X-factor
          mtp.xfactor = 5 + mtp.bat_average - mtp.bowl_average + (mtp.catches / mtp.matchcount)
        end
      when MatchType::ODI
dprint 'ODI' # debug
        if mtp.runs < 500 || mtp.bat_average < 20 || mtp.wickets < 50
          # Doesn't qualify
          mtp.unset(:xfactor)
        else
          # ODI X-factor
          #             Compare batting strikerate with economy        Compare balls faced per innings with bowling strikerate    Add catches per match
          mtp.xfactor = mtp.bat_strikerate - (mtp.economy * 100 / 6) + (mtp.balls / mtp.completed) - mtp.bowl_strikerate          + (mtp.catches / mtp.matchcount)
        end
      when MatchType::T20I
dprint 'T20I' # debug
        if mtp.runs < 150 || mtp.bat_average < 10 || mtp.wickets < 15
          # Doesn't qualify
          mtp.unset(:xfactor)
        else
          # T20I X-factor
          #             Compare batting strikerate with economy        Compare balls faced per innings with bowling strikerate    Add catches per match
          mtp.xfactor = mtp.bat_strikerate - (mtp.economy * 100 / 6) + (mtp.balls / mtp.completed) - mtp.bowl_strikerate          + (mtp.catches / mtp.matchcount)
        end
      else
        dprint "Unknown match type: #{mtp.type_number}", :red
      end
    end

dprint "[#{mtp.matchcount}|#{mtp.runs}|#{mtp.bat_average}|#{mtp.wickets}|#{mtp.bowl_average}|#{mtp.catches}|#{mtp.bowl_strikerate}|#{mtp.economy}]", :pink # debug
dputs mtp.xfactor.nil? ? "X" : mtp.xfactor, :white # debug

    mtp.save
  end

  #----------------------------------------------------------------------------
  # Update cumulative statistics from performance data
  def self::update_statistics mtp, do_fielding=true
    # Get fielding statistics
    if do_fielding
      self::get_fielding_statistics mtp
    else
      mtp.update_names
    end

    # Process performance data
    match_type_player_id     = mtp._id
dputs "#{mtp.name} (#{match_type_player_id})", :white # debug

    performances  = Performance.where(match_type_player_id: match_type_player_id)

    # A player may have no performances, in which case we don't need them
    if performances.length == 0
      dputs 'No performances', :red
      mtp.destroy
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
#-dprint 'batting...', :cyan # debug
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

        if completed > 0
          bat_average = runs.to_f / completed.to_f
          pf.average  = bat_average
        end

        if balls > 0
          bat_strikerate    = 100 * runs.to_f / balls.to_f
          pf.cum_strikerate = bat_strikerate
        end
#-dprint 'batting finished', :cyan # debug
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
    mtp.innings          = innings
    mtp.completed        = completed
    mtp.runs             = runs
    mtp.minutes          = minutes
    mtp.balls            = balls
    mtp.fours            = fours
    mtp.sixes            = sixes
    mtp.bat_average      = bat_average     if completed > 0
    mtp.bat_strikerate   = bat_strikerate  if balls > 0
#-dprint '-batting2', :cyan # debug

    # Rationalise overs and odd balls
    if ballsdelivered > 0
      overs     = (ballsdelivered / 6).floor.to_i
      oddballs  = ballsdelivered % 6
    end

    # Overall bowling
    mtp.overs            = overs
    mtp.oddballs         = oddballs
    mtp.overs_string     = overs_string
    mtp.maidens          = maidens
    mtp.runsconceded     = runsconceded
    mtp.wickets          = wickets
    mtp.bowl_average     = bowl_average                    if wickets > 0
    mtp.bowl_strikerate  = bowl_strikerate                 if wickets > 0
    mtp.economy          = runsconceded.to_f / overs_float if overs_float > 0
#-dprint '-bowling2', :cyan # debug

    # Overall fielding
    mtp.dismissals       = dismissals
    mtp.catches_total    = catches_total
    mtp.stumpings        = stumpings
    mtp.catches_wkt      = catches_wkt
    mtp.catches          = catches
#-dprint '-fielding2', :cyan # debug

#-dputs mtp.inspect # debug

    # X-factor
    self::update_xfactor mtp

    # Control
    mtp.dirty            = false
dputs mtp.inspect, :white # debug
    mtp.save
  end

  def self::update_dirty_players
    # Recompile aggregate stats for players with
    # new performance information
    self::dirty.each do |mtp|
      update_statistics mtp
    end
  end

  def self::update player_ref
    player_list = self::where player_ref:player_ref

    player_list.each do |mtp|
dputs mtp.inspect # debug
      update_statistics mtp unless mtp.nil?
    end
  end
end
