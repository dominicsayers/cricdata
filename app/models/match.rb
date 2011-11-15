class Match
  include Mongoid::Document

  # Fields
  field :match_id,    :type => String
  field :parsed,      :type => Boolean
  field :serial,      :type => Integer

  key :match_id

  # Validations

  # Scopes
  scope :unparsed, where(:parsed.ne => true)

  # Relationships
  belongs_to :match_type
  belongs_to :ground
  has_many :innings

  # Helpers
  def self::update_performance pf
    return unless pf.has_key? :id
dputs pf.inspect # debug

    inning = @match.innings.find_or_create_by(inning_number: @inning)

    if pf[:id] == 0
      # Record innings analysis
      if pf[:name].downcase == 'extras'
        inning.extras          = pf[:runs]
        inning.extras_analysis = pf[:howout]
      else
        inning.summary         = pf[:howout]
      end
    else
      # Make sure player exists
      player = Player.find_or_create_by(player_id: pf[:id])
      player.name = pf[:name]
      player.save

      performance = inning.performances.find_or_create_by(player_id: pf[:id])

      if pf[:bowling].length == 0
        # Record batting analysis
        performance.runs          = pf[:runs]
        performance.minutes       = pf[:batting][0]
        performance.balls         = pf[:batting][1]
        performance.fours         = pf[:batting][2]
        performance.sixes         = pf[:batting][3]
        performance.strikerate    = pf[:batting][4]
        performance.howout        = pf[:howout]
        performance.notout        = pf[:howout].downcase == 'not out'
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

  def self::parse_next
    # Find next unparsed match and parse it
    @match           = self::unparsed.first

    return false if @match.nil?

    match_id         = @match.match_id

    # Add any new matches on this page
    url             = 'http://www.espncricinfo.com/ci/engine/match/%s.json' % match_id
    doc             = get_data url

    # Match type & serial number
    href            = '/ci/engine/records/index.html?class='
    href_len        = href.length
    type_node       = doc.xpath("//a[substring(@href,1,#{href_len})='#{href}']").first
    href            = type_node.attributes['href'].value
    text            = type_node.children.first.content
    type_id         = href[href_len..-1]
    text_to_a       = text.split(' no. ')
    type_name       = text_to_a.first
    match_serial    = text_to_a.last
dputs text, :white # debug

    # Ground
    href            = '/ci/content/ground/'
    href_len        = href.length
    ground_node     = doc.xpath("//a[substring(@href,1,#{href_len})='#{href}']").first
    href            = ground_node.attributes['href'].value
    ground_name     = ground_node.children.first.content
    ground_id       = href[href_len..-1].split('.').first
dputs ground_name, :white # debug

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
        pf[:id]     = href[href_len..-1].split('.').first
      when :inningsDetails
        # Innings summary, so save the previous player
        update_performance pf

        pf          = { :batting => [], :bowling => [] } # Clear down for next player

        pf[:name]   = text
        pf[:id]     = 0
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
    # Match type
    match_type        = MatchType.find_or_create_by(type_id: type_id)
    match_type.name   = type_name
    match_type.save

    # Ground
    ground            = Ground.find_or_create_by(ground_id: ground_id)
    ground.name       = ground_name
    ground.save

    # Match
    @match.match_type = match_type
    @match.ground     = ground
    @match.serial     = match_serial
    @match.parsed     = true
    @match.save

    return true
  end

  def self::parse_all
    # Parse all unparsed matches
    loop do
      break unless parse_next
    end
  end
end
