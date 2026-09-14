module Persistence
  module_function

  def adapter
    ENV.fetch("PERSISTENCE_ADAPTER", "active_record")
  end

  def active_record?
    adapter == "active_record"
  end

  def json_directory?
    adapter == "json_directory"
  end

  def validate!
    return if active_record? || json_directory?

    raise ArgumentError, "unsupported PERSISTENCE_ADAPTER"
  end

  def transaction(&block)
    validate!
    return yield unless active_record?

    ActiveRecord::Base.transaction(&block)
  end
end
