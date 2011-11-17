class Ground
  include Mongoid::Document

  # Fields
  field :ground_ref, :type => Integer
  field :name, :type => String

  key :ground_ref

  # Validations

  # Scopes

  # Relationships
  has_many :matches

  # Helpers
end
