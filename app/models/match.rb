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
  def self::update_performance pf
    return unless pf.has_key? :ref
dputs pf.inspect # debug

    inning = @match.innings.find_or_create_by inning_number: @inning

    if pf[:ref] == 0
      # Record innings analysis
      if pf[:name].downcase == 'extras'
        inning.extras          = pf[:runs]
        inning.extras_analysis = pf[:howout]
      else
        inning.summary         = pf[:howout]
      end
    else
      # Make sure player exists
      player        = Player.find_or_create_by type_number:@match.match_type.type_number, player_ref:pf[:ref]
      player.name   = pf[:name]
      player.dirty  = true
      player.save

      performance = inning.performances.find_or_create_by player_id: player._id

      if pf[:bowling].length == 0
        # Record batting analysis
        performance.runs          = pf[:runs]
        performance.minutes       = pf[:batting][0]
        performance.balls         = pf[:batting][1]
        performance.fours         = pf[:batting][2]
        performance.sixes         = pf[:batting][3]
        performance.strikerate    = pf[:batting][4]
        performance.howout        = pf[:howout]
        performance.notout        = pf[:howout].downcase.in?(['not out', 'retired hurt', 'absent hurt'])
      else
        # Record bowling analysis
        overs = pf[:bowling][0]
        o_and_b = overs.split('.')

        if o_and_b.length == 2
          overs = o_and_b.first
          balls = o_and_b.last
        else
          balls = 0
        end

        performance.overs         = overs
        performance.oddballs      = balls
        performance.maidens       = pf[:bowling][1]
        performance.runsconceded  = pf[:bowling][2]
        performance.wickets       = pf[:bowling][3]
        performance.economy       = pf[:bowling][4]
        performance.extras        = pf[:bowling][5]
      end

      performance.save
    end

    inning.save
  end

  def self::parse match_ref=0
    @match = self::where(match_ref: match_ref.to_s).first unless match_ref == 0

    return false if @match.nil?

    match_ref         = @match.match_ref

    # Get match data
    raw_match       = RawMatch.find_or_create_by(match_ref: match_ref)

    if raw_match.zhtml.blank?
      url             = 'http://www.espncricinfo.com/ci/engine/match/%s.json?view=scorecard' % match_ref
      raw_match.zhtml  = BSON::Binary.new(Zlib::Deflate.deflate(get_response(url)))
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

    # Innings
    inning_nodeset = doc.xpath("//tr[@class='inningsRow']/td")
    @inning        = 1
    parsing_bowling = false
    pf              = {} # Performance hash

    inning_nodeset.each do |inning_node|
      classattr   = inning_node.attributes['class']
      classname   = classattr.nil? ? '' : classattr.value
      firstchild  = inning_node.children.first
      text        = !firstchild.nil? && firstchild.text? ? firstchild.content.strip : ''

      case classname.to_sym
      when :playerName
        # This is the next player, so save the previous one
        update_performance pf

        pf          = { :batting => [], :bowling => [] } # Clear down for next player

        player_node = firstchild
        href        = '/ci/content/player/'
        href_len    = href.length
        href        = player_node.attributes['href'].value
        pf[:name]   = player_node.children.first.content
        pf[:ref]    = href[href_len..-1].split('.').first
      when :inningsDetails
        # Innings summary, so save the previous player
        update_performance pf

        pf          = { :batting => [], :bowling => [] } # Clear down for next player

        pf[:name]   = text
        pf[:ref]    = 0
      when :battingDismissal
        if parsing_bowling
          # When we go from bowling performances to batting, that's the start of the next innings
          @inning += 1
          parsing_bowling = false
        end

        pf[:howout]     = text
      when :battingRuns
        pf[:runs]       = text
      when :battingDetails
        pf[:batting]    << text
      when :bowlingDetails
        parsing_bowling = true
        pf[:bowling]    << text
      end
    end

    # Save the last player/innings
    update_performance pf

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
