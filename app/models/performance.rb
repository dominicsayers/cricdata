class Performance
  include Mongoid::Document

  # Fields
  # Batting
  field :runs,            :type => Integer
  field :minutes,         :type => Integer
  field :balls,           :type => Integer
  field :fours,           :type => Integer
  field :sixes,           :type => Integer
  field :strikerate,      :type => Float
  field :howout,          :type => String
  field :notout,          :type => Boolean

  # Bowling
  field :overs,           :type => Integer
  field :oddballs,        :type => Integer
  field :maidens,         :type => Integer
  field :runsconceded,    :type => Integer
  field :wickets,         :type => Integer
  field :economy,         :type => Float
  field :extras,          :type => String

  # Fielding
  field :dismissals,      :type => Integer
  field :catches_total,   :type => Integer
  field :stumpings,       :type => Integer
  field :catches_wkt,     :type => Integer
  field :catches,         :type => Integer # Not as a wicketkeeper

  # Cumulative
  field :average,         :type => Float
  field :cum_strikerate,  :type => Float
  field :cum_economy,     :type => Float

  index([ [:inning_id, Mongo::ASCENDING], [:match_type_player_id, Mongo::ASCENDING] ], unique: true)
  index([ [:match_type_player_id, Mongo::ASCENDING], [:inning_id, Mongo::ASCENDING] ], unique: true)
  index :runs

  # Validations

  # Scopes
  default_scope asc(:inning_id, :match_type_player_id)
  scope :batting, where(:runs.exists => true)
  scope :bowling, where(:runs.exists => false)

  # Relationships
  belongs_to :match_type_player
  belongs_to :inning

  # Helpers
end
