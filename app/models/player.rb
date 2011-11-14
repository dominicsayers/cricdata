class Player
  include Mongoid::Document

  # Fields
  field :player_id, :type => Integer
  field :name, :type => String

  key :player_id

  # Validations

  # Scopes

  # Relationships
  has_many :performances

  # Helpers
end
