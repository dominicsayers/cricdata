class Player
  include Mongoid::Document

  # Fields
  field :slug,        :type => String
  field :name,        :type => String
  field :fullname,    :type => String
  field :master_ref,  :type => Integer
  field :player_refs, :type => Array # If there's more than one, this is a disambiguation page

  key :slug

  index :master_ref
  index :player_refs

  # Validations

  # Scopes

  # Relationships
  has_many :match_type_players

  # Helpers
end
