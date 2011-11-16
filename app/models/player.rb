class Player
  include Mongoid::Document

  # Fields
  # Basic
  field :player_id,       :type => Integer
  field :name,            :type => String
  field :dirty,           :type => Boolean

  # Stats
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

  key :player_id

  # Validations

  # Scopes
  scope :dirty, where(dirty: true)

  # Relationships
  has_many :performances

  # Helpers
  def self::update_dirty_players
    # Recompile aggregate stats for players with
    # new performance information
    self::dirty.each do |player|
      player_id     = player.player_id
dputs "#{player.name} (#{player_id})", :white # debug

      performances  = Performance.where(player_id: player_id.to_s)

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

      # Examine performances
      performances.each do |pf|
        if pf.overs.nil?
          # Batting stats
          innings     += 1
          completed   += 1 unless pf.notout
          runs        += pf.runs
          minutes     += pf.minutes
          balls       += pf.balls
          fours       += pf.fours
          sixes       += pf.sixes

          if completed > 0
            bat_average = runs / completed
            pf.average  = bat_average
          end

          if balls > 0
            bat_strikerate    = 100 * runs / balls
            pf.cum_strikerate = bat_strikerate
          end
        else
          # Bowling stats
          overs         += pf.overs
          oddballs      += pf.oddballs
          maidens       += pf.maidens
          runsconceded  += pf.runsconceded
          wickets       += pf.wickets

          # Assume 6-ball overs for now
          if pf.wickets > 0
            pf.strikerate = (pf.oddballs + 6 * pf.overs) / pf.wickets
          end

          # Parse overs and odd balls into useful numbers
          ballsdelivered  = oddballs + (6 * overs)
          remainder       = ballsdelivered % 6
          overs_float     = ballsdelivered / 6
          overs_string    = overs_float.floor.to_s
          overs_string    += '.' + remainder.to_s if remainder

          if wickets > 0
            bowl_average      = runs / wickets
            pf.average        = bowl_average
            bowl_strikerate   = ballsdelivered / wickets
            pf.cum_strikerate = bowl_strikerate
          end

          if overs_float > 0
            pf.cum_economy = runsconceded / overs_float
          end
        end
dputs pf.inspect # debug
        pf.save
#-dputs player.bat_average, :cyan # debug
#-dputs bat_average, :pink # debug
      end

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
      player.bowl_average     = bowl_average                if wickets > 0
      player.bowl_strikerate  = bowl_strikerate             if wickets > 0
      player.economy          = runsconceded / overs_float  if overs_float > 0

      # Control
      player.dirty            = false
dputs player.inspect # debug
      player.save
    end
  end

  def self::mark_all_dirty
    self::all.each do |player|
      player.dirty = true
dputs player.inspect # debug
      player.save
    end
  end
end
