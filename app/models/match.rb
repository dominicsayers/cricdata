# frozen_string_literal: true

require 'json'

class Match
  include Mongoid::Document

  # Fields
  field :match_ref,   type: String
  field :parsed,      type: Boolean
  field :serial,      type: Integer
  field :date_start,  type: Date
  field :date_end,    type: Date
  field :home_team,   type: String
  field :away_team,   type: String

  #  key :match_ref
  index({ match_ref: 1 }, { unique: true })

  # Validations

  # Scopes
  scope :unparsed, -> { where(:parsed.ne => true) }

  # Relationships
  belongs_to :match_type, optional: true
  belongs_to :ground, optional: true
  has_many :innings, dependent: :restrict_with_exception

  PLAYER_REF_PATH = '/ci/content/player/'
  PLAYER_REF_PATH_LENGTH = PLAYER_REF_PATH.length

  def to_s
    "#{match_ref}: #{home_team} v #{away_team} on #{date_start}"
  end

  def stats_template(nodeset)
    template = []

    nodeset.each do |inning_header_node|
      # Gather the column headings: R M B 4s 6s SR etc. (or O M R W for bowling stats)
      text = inning_header_node.children.empty? ? :Extras : inning_header_node.children.first.text
      text = :Extras if text.nil?
      template << text.to_sym
    end

    # -dputs template, :yellow # debug
    template
  end

  def player_details_from(node)
    href = node.attributes['href'].value
    ref = href.split('/').last.split('.').first.to_i
    # -dp "#{node.children.first.content} (#{ref})", :blue # debug
    { name: node.children.first.content, ref: ref }
  end

  # Helpers
  def self.parse(match_ref = 0)
    @match = where(match_ref: match_ref.to_s).first unless match_ref.zero?

    return false if @match.nil?

    match_ref = @match.match_ref
    recent_match = @match.date_end.blank? ? true : @match.date_end > 1.week.ago.to_date
    dputs "Parsing match #{match_ref}", :white

    # Get match data
    raw_match = RawMatch.find_or_create_by(match_ref: match_ref)
    # -dp raw_match, :cyan # debug

    if recent_match || raw_match.match_json.blank?
      url = format('https://www.espncricinfo.com/ci/engine/match/%<match_ref>s.json', match_ref: match_ref)
      raw_match.match_json = get_response(url)
      url += '?view=scorecard'
      raw_match.scorecard_html = get_response(url)
      raw_match.save
    end

    json = JSON.parse(raw_match.match_json)
    match = json['match']
    match_teams = [match['team1_name'], match['team2_name']]

    # dputs match, :pink # debug

    # Get date(s) and ground name
    @match.home_team   = match_teams[0]
    @match.away_team   = match_teams[1]
    @match.date_start  = match['start_date_raw'].to_date
    @match.date_end    = match['end_date_raw'].to_date

    # Match type - update collection
    match_type        = MatchType.find_or_create_by(type_number: match['international_class_id'].to_i)
    match_type.name   = match['international_class_name']
    match_type.save

    # Ground - update collection
    ground            = Ground.find_or_create_by(ground_ref: match['ground_id'].to_i)
    ground.name       = match['ground_name']
    ground.save

    # Match details
    @match.match_type = match_type
    @match.ground     = ground
    @match.serial     = match['international_number'].to_i

    doc = Nokogiri::HTML(raw_match.scorecard_html)

    # Check which columns are available
    # Innings header
    # We don't know which batting stats were recorded for this innings
    stats_template = {}
    stats = {}
    innings_teams = {}

    (1..4).each do |inning_number|
      stats_template[inning_number] = {}

      borb = :batting
      inning_node = doc.xpath("//table[@class='inningsTable'][@id='inningsBat#{inning_number}']")
      inning_header_nodeset = inning_node.xpath("tr[@class='inningsHead']")
      stats_template[inning_number][borb] = @match.stats_template(inning_header_nodeset.xpath('td/b'))

      # Which team is batting?
      inning_description_nodeset = inning_header_nodeset.xpath("td[@colspan='2']")

      unless inning_description_nodeset.children.empty?
        inning_description = inning_description_nodeset.children.first.content
        /(.*?)(?: 1st| 2nd)* Innings/i.match(inning_description)
        batting_team = ::Regexp.last_match(1)

        # Which team is bowling?
        i = match_teams.index batting_team

        unless i.nil?
          innings_teams[inning_number] = {} unless innings_teams.key? inning_number
          innings_teams[inning_number][:batting] = i
          innings_teams[inning_number][:bowling] = 1 - i
        end
      end

      stats[inning_number] = { batting: [], bowling: [] }

      # Innings (batting data)
      inning_nodeset  = inning_node.xpath("tr[@class='inningsRow']/td")
      pf              = {}
      stats_counter   = 0

      inning_nodeset.each do |inning_nodeset_item|
        # If it isn't headed XXX [nth] Innings then ignore it
        next unless innings_teams.key? inning_number

        dputs "Parsing innings #{inning_number}...", :white

        classattr   = inning_nodeset_item.attributes['class']
        classname   = classattr.nil? ? '' : classattr.value
        firstchild  = inning_nodeset_item.children.first
        text        = !firstchild.nil? && firstchild.text? ? firstchild.content.strip : ''
        # -dputs classname, :cyan # debug
        # -dputs text, :cyan # debug

        case classname.to_sym
        when :playerName
          stats[inning_number][borb] << pf unless pf == {} # save current performance hash

          # This is the next player, so start a new performance hash
          pf = @match.player_details_from(firstchild)
          stats_counter = 0
        when :inningsDetails
          stats[inning_number][borb] << pf unless pf == {} # save current performance hash

          # This is the innings summary, so start a new performance hash
          pf = { ref: 0, name: text }
          stats_counter  = 0
        when :battingDismissal
          pf[:howout]    = text
        when :battingRuns, :battingDetails
          key = stats_template[inning_number][borb][stats_counter]
          stats_counter += 1
          pf[key] = text
        end
      end

      pf[:ref] = 0 if !pf.empty? && pf[:ref].nil? # ensure ref is always present

      stats[inning_number][borb] << pf unless pf == {} # save current performance hash

      # Innings (bowling data)
      borb = :bowling
      inning_node = doc.xpath("//table[@class='inningsTable'][@id='inningsBowl#{inning_number}']")
      inning_header_nodeset = inning_node.xpath("tr[@class='inningsHead']")
      stats_template[inning_number][borb] = @match.stats_template(inning_header_nodeset.xpath('td/b'))
      inning_nodeset  = inning_node.xpath("tr[@class='inningsRow']/td")

      pf              = {}
      stats_counter   = 0

      inning_nodeset.each do |inning_nodeset_item|
        # If it isn't headed XXX [nth] Innings then ignore it
        next unless innings_teams.key? inning_number

        classattr   = inning_nodeset_item.attributes['class']
        classname   = classattr.nil? ? '' : classattr.value
        firstchild  = inning_nodeset_item.children.first
        text        = !firstchild.nil? && firstchild.text? ? firstchild.content.strip : ''
        # -dputs classname, :cyan # debug
        # -dputs text, :cyan # debug

        case classname.to_sym
        when :playerName
          stats[inning_number][borb] << pf unless pf == {} # save current performance hash

          # This is the next player, so start a new performance hash
          player_details = @match.player_details_from(firstchild)
          pf             = { name: player_details[:name], ref: player_details[:ref] }
          stats_counter = 0
        when :bowlingDetails
          key = stats_template[inning_number][borb][stats_counter]
          stats_counter += 1
          pf[key] = text
        end
      end

      stats[inning_number][borb] << pf unless pf == {}

      # -dputs stats, :white # debug

      # Now we have the stats gathered into a hash, we can parse out the
      # players' performmances
      break unless stats.key? inning_number
      break unless stats[inning_number].key? :batting

      if stats[inning_number][:batting].empty?
        inning_number > 2 ? break : next
      end

      dputs "Processing innings #{inning_number}", :white

      inning      = @match.innings.find_or_create_by inning_number: inning_number
      type_number = @match.match_type.type_number

      # Batting
      stats[inning_number][:batting].each do |p|
        # -dp p, :white # debug
        if (p[:ref]).zero?
          # Record innings analysis
          if p[:name] && p[:name].downcase == 'extras'
            inning.extras          = p[:R]
            inning.extras_analysis = p[:howout]
          else
            inning.summary         = p[:howout]
          end
        elsif p[:howout].downcase.in?(['absent hurt', 'absent ill', 'absent'])
          # Not a performance so don't record anything
          dputs p[:howout], :pink
        else
          # Make sure player exists
          mtp        = MatchTypePlayer.find_or_create_by type_number: type_number, player_ref: p[:ref]
          mtp.name   = p[:name]
          mtp.dirty  = true
          mtp.update_names
          mtp.save!

          inning.save!
          performance = inning.performances.find_or_create_by! match_type_player_id: mtp._id

          # Record batting analysis
          performance.runs          = p[:R]
          performance.minutes       = p[:M]
          performance.balls         = p[:B]
          performance.fours         = p[:'4s']
          performance.sixes         = p[:'6s']
          performance.strikerate    = p[:SR]
          performance.howout        = p[:howout]
          performance.notout        = p[:howout].downcase.in?(['not out', 'retired hurt'])

          performance.type_number   = type_number
          performance.date_start    = @match.date_start
          performance.name          = p[:name]

          performance.save

          IndividualScore.register inning, mtp, performance.runs, @match.date_start, performance.notout
        end
      end

      inning.batting_team = match_teams[innings_teams[inning_number][:batting]]
      inning.bowling_team = match_teams[innings_teams[inning_number][:bowling]]
      inning.save
      # -dputs inning, :yellow # debug

      stats[inning_number][:bowling].each do |p|
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
        mtp.update_names
        mtp.save

        performance = inning.performances.find_or_create_by match_type_player_id: mtp._id

        performance.overs         = overs
        performance.oddballs      = balls
        performance.maidens       = p[:M]
        performance.runsconceded  = p[:R]
        performance.wickets       = p[:W]
        performance.economy       = p[:Econ]
        performance.extras        = p[:Extras]

        performance.type_number   = type_number
        performance.date_start    = @match.date_start
        performance.name          = p[:name]

        performance.save
        # -dp performance # debug
      end
    end

    # Wrap up
    @match.parsed = (@match.date_end < Time.zone.today) # Only count completed matches as parsed
    @match.save

    dputs "Match #{match_ref} parsed", :green
    true
  end

  def self.parse_next
    # Find next unparsed match and parse it
    @match = unparsed.first
    parse
  end

  def self.parse_all
    # Parse all unparsed matches
    where(parsed: false).sort(date_start: 1).each do |match|
      @match = match
      parse
    end
  end

  def self.mark_all_unparsed
    where(:parsed.ne => false).each do |match|
      match.parsed = false
      # -dputs match.inspect # debug
      match.save
    end
  end
end
