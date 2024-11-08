class Settings
  include Mongoid::Document

  # Fields
  field :name, type: String
  field :value, type: String
  #  key :name
  index({ name: 1 }, { unique: true })

  # Validations

  # Scopes

  # Helpers
  def self.get(name)
    setting = find_or_create_by(name: name)
    setting.value
  end

  def self.set(name, value)
    setting = find_or_create_by(name: name)
    setting.value = value
    setting.save
  end
end
