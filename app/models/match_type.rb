class MatchType
  include Mongoid::Document

  NONE  = 0 # Will never be used as a type_number
  TEST  = 1
  ODI   = 2
  T20I  = 3

  # Fields
  field :type_number, :type => Integer
  field :name,        :type => String

  key :type_number

  # Validations

  # Scopes

  # Relationships
  has_many :matches
end
