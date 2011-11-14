class MatchType
  include Mongoid::Document

  # Fields
  field :type_id, :type => Integer
  field :name, :type => String

  key :type_id

  # Validations

  # Scopes

  # Relationships
  has_many :matches
end
