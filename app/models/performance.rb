# frozen_string_literal: true

class Performance
  include Mongoid::Document

  # Fields
  # Batting
  field :runs,            type: Integer
  field :minutes,         type: Integer
  field :balls,           type: Integer
  field :fours,           type: Integer
  field :sixes,           type: Integer
  field :strikerate,      type: Float
  field :howout,          type: String
  field :notout,          type: Boolean

  # Bowling
  field :overs,           type: Integer
  field :oddballs,        type: Integer
  field :maidens,         type: Integer
  field :runsconceded,    type: Integer
  field :wickets,         type: Integer
  field :economy,         type: Float
  field :extras,          type: String

  # Fielding
  field :dismissals,      type: Integer
  field :catches_total,   type: Integer
  field :stumpings,       type: Integer
  field :catches_wkt,     type: Integer
  field :catches,         type: Integer # Not as a wicketkeeper

  # Cumulative
  field :average,         type: Float
  field :cum_strikerate,  type: Float
  field :cum_economy,     type: Float

  # Reporting
  field :type_number,     type: Integer
  field :date_start,      type: Date
  field :name,            type: String
  field :for_team,        type: String

  # Indexes
  index({ inning_id: 1, match_type_player_id: 1 }, { unique: true })
  index({ match_type_player_id: 1, inning_id: 1 }, { unique: true })
  index({ type_number: 1, date_start: 1, runs: 1 }, { unique: false })
  index({ runs: 1 })

  # Validations

  # Scopes
  scope :batting, -> { where(:runs.exists => true) }
  scope :bowling, -> { where(:runs.exists => false) }
  #  default_scope asc(:inning_id, :match_type_player_id)

  # Relationships
  belongs_to :match_type_player
  belongs_to :inning
  belongs_to :player, optional: true

  # Helpers
end
