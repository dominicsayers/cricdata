class MatchType
  include Mongoid::Document

  # Fields
  field :type_number, :type => Integer
  field :name, :type => String

  key :type_number

  # Validations

  # Scopes

  # Relationships
  has_many :matches
end
