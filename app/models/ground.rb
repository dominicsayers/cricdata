class Ground
  include Mongoid::Document

  # Fields
  field :ground_id, :type => Integer
  field :name, :type => String

  key :ground_id

  # Validations

  # Scopes

  # Relationships
  has_many :matches

  # Helpers
end
