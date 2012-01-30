class Match
  include Mongoid::Document

  # Fields
  field :match_ref,   :type => String
  field :parsed,      :type => Boolean
  field :serial,      :type => Integer
  field :date_start,  :type => Date
  field :date_end,    :type => Date

  key :match_ref
  index :match_ref, unique: true

  # Validations

  # Scopes
  scope :unparsed, where(:parsed.ne => true)

  # Relationships
  belongs_to :match_type
  belongs_to :ground
  has_many :innings

  # Helpers
  def self::parse match_ref=0
    @match = self::where(match_ref: match_ref.to_s).first unless match_ref == 0

    return false if @match.nil?

    match_ref = @match.match_ref
    recent_match = @match.date_end.blank? ? true : @match.date_end > 1.week.ago.to_date

    # Get match data
    raw_match = RawMatch.find_or_create_by(match_ref: match_ref)

    if recent_match or raw_match.zhtml.blank?
      url             = 'http://www.espncricinfo.com/ci/engine/match/%s.json?view=scorecard' % match_ref
      raw_match.zhtml = BSON::Binary.new(Zlib::Deflate.deflate(get_response(url)))
      raw_match.save
    end

    doc = Nokogiri::HTML(Zlib::Inflate.inflate(raw_match.zhtml.to_s))

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

    @match.date_start  = Date.new(y1.to_i, m1n, d1.to_i)
    @match.date_end    = Date.new(y2.to_i, m2n, d2.to_i)

    # Match type & serial number
    href            = '/ci/engine/records/index.html?class='
    href_len        = href.length
    type_node       = doc.xpath("//a[substring(@href,1,#{href_len})='#{href}']").first
    href            = type_node.attributes['href'].value
    text            = type_node.children.first.content
    type_number     = href[href_len..-1].to_i
    text_to_a       = text.split(' no. ')
    type_name       = text_to_a.first
    match_serial    = text_to_a.last
dputs text, :white # debug

    # Match type - update collection
    match_type        = MatchType.find_or_create_by(type_number: type_number)
    match_type.name   = type_name
    match_type.save

    # Ground
    href            = '/ci/content/ground/'
    href_len        = href.length
    ground_node     = doc.xpath("//a[substring(@href,1,#{href_len})='#{href}']").first
    href            = ground_node.attributes['href'].value
    ground_name     = ground_node.children.first.content
    ground_ref      = href[href_len..-1].split('.').first
dputs ground_name, :white # debug

    # Ground - update collection
    ground            = Ground.find_or_create_by(ground_ref: ground_ref)
    ground.name       = ground_name
    ground.save

    # Match details
    @match.match_type = match_type
    @match.ground     = ground
    @match.serial     = match_serial

    # Check which columns are available
    # Innings header
    # We don't know which batting stats were recorded for this innings
    inning_nodeset  = doc.xpath("//tr[@class='inningsHead']")
    inning_number   = 1
    borb            = :batting
    stats_template  = {}

    inning_nodeset.each do |inning_node|
      inning_header_nodeset = inning_node.xpath('td/b')
      stats_template[inning_number] = {:batting => [], :bowling => []} unless stats_template.has_key? inning_number
#-dputs borb
#-dputs "Innings #{inning_number}"

      inning_header_nodeset.each do |inning_header_node|
        # Gather the column headings: R M B 4s 6s SR etc.
#-dp inning_header_node, :pink
#-dputs inning_header_node.children.length, :pink
        text = inning_header_node.children.length == 0 ? :Extras : inning_header_node.children.first.text
        text = :Extras if text.nil?
        stats_template[inning_number][borb] << text.to_sym
      end
#-dp stats_template[inning_number][borb]

      if borb == :bowling
        inning_number += 1
        borb = :batting
      else
        borb = :bowling
      end
    end
#-dp stats_template, :cyan

    # Innings
    inning_nodeset  = doc.xpath("//tr[@class='inningsRow']/td")
    inning_number   = 1
    borb            = :batting
    stats           = {}
    pf              = {}
    stats_counter   = 0

    inning_nodeset.each do |inning_node|
      classattr   = inning_node.attributes['class']
      classname   = classattr.nil? ? '' : classattr.value
      firstchild  = inning_node.children.first
      text        = !firstchild.nil? && firstchild.text? ? firstchild.content.strip : ''

      stats[inning_number] = {:batting => [], :bowling => []} unless stats.has_key? inning_number

      case classname.to_sym
      when :playerName
        stats[inning_number][borb] << pf unless pf == {} # save current performance hash

        # This is the next player, so start a new performance hash
        player_node   = firstchild
        href          = '/ci/content/player/'
        href_len      = href.length
        href          = player_node.attributes['href'].value
        pf            = {name:player_node.children.first.content, ref:href[href_len..-1].split('.').first}
        stats_counter = 0
      when :inningsDetails
        stats[inning_number][borb] << pf unless pf == {} # save current performance hash

        # Innings summary, so start a new performance hash
        pf            = {name:text, ref:0}
        stats_counter = 0
      when :battingDismissal
        if borb == :bowling
          # When we go from bowling performances to batting, that's the start of the next innings
          inning_number += 1
          borb          = :batting
          stats_counter = 0
        end

        pf[:howout]     = text
      when :battingRuns, :battingDetails
        key             = stats_template[inning_number][borb][stats_counter]
        stats_counter   += 1
        pf[key]         = text
      when :bowlingDetails
        if borb == :batting
          borb          = :bowling
          stats_counter = 0
        end

        key             = stats_template[inning_number][borb][stats_counter]
        stats_counter   += 1
        pf[key]         = text
      end
    end

    stats[inning_number][borb] << pf unless pf == {} # save current performance hash

    # Now we have the stats gathered into a hash, we can parse out the
    # players' performmances
    for inning_number in 1..4
      break unless stats.has_key? inning_number

      inning      = @match.innings.find_or_create_by inning_number: inning_number
      type_number = @match.match_type.type_number

      # Batting
      stats[inning_number][:batting].each do |p|
dp p, :white
        if p[:ref] == 0
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

          performance.type_number   = type_number
          performance.date_start    = @match.date_start
          performance.name          = p[:name]

          performance.save
dp performance

          IndividualScore.register inning, mtp, performance.runs, @match.date_start, performance.notout
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

    # Wrap up
    @match.parsed = (@match.date_end < Date.today) # Only count completed matches as parsed
    @match.save

    return true
  end

  def self::parse_next
    # Find next unparsed match and parse it
    @match = self::unparsed.first
    self::parse
  end

  def self::parse_all
    # Parse all unparsed matches
    self::where(parsed:false).each do |match|
      @match = match
      self::parse
    end
  end

  def self::mark_all_unparsed
    self::where(:parsed.ne => false).each do |match|
      match.parsed = false
dputs match.inspect # debug
      match.save
    end
  end
end
