class Performance
  include Mongoid::Document

  # Fields
#-  field :match_id,      :type => Integer
#-  field :inning_number,       :type => Integer
#-  field :player_id,     :type => Integer
  field :runs,          :type => Integer
  field :minutes,       :type => Integer
  field :balls,         :type => Integer
  field :fours,         :type => Integer
  field :sixes,         :type => Integer
  field :strikerate,    :type => Integer
  field :howout,        :type => String
  field :notout,        :type => Boolean
  field :overs,         :type => Integer
  field :oddballs,      :type => Integer
  field :maidens,       :type => Integer
  field :runsconceded,  :type => Integer
  field :wickets,       :type => Integer
  field :economy,       :type => Float
  field :extras,        :type => String

  key :inning_id, :player_id

  # Validations

  # Scopes
  default_scope asc(:inning_id, :player_id)

  # Relationships
  belongs_to :player
  belongs_to :inning

  # Helpers
end
