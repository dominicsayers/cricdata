# frozen_string_literal: true

class Ground
  include Mongoid::Document

  # Fields
  field :ground_ref, type: Integer
  field :name, type: String

  #  key :ground_ref
  index({ ground_ref: 1 }, { unique: true })

  # Validations

  # Scopes

  # Relationships
  has_many :matches, dependent: :restrict_with_exception

  # Helpers
end
