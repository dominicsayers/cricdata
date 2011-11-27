class Player
  include Mongoid::Document

  # Fields
  field :slug, :type => String
  field :player_refs, :type => Array # If there's more than one, this is a disambiguation page

  key :slug

  index :player_refs

  # Validations

  # Scopes

  # Relationships
  has_many :match_type_players

  # Helpers
end
