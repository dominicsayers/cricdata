# frozen_string_literal: true

module ConsoleLog
  def ansi(color)
    case color.to_sym
    when :gray then 30
    when :red then 31
    when :green then 32
    when :yellow then 33
    when :blue then 34
    when :cyan then 36
    when :white then 37
    else; 35 # magenta (pink)
    end
  end

  def dputs(message, color = :yellow)
    Rails.logger.debug { "\e[#{ansi color};1m#{message}\e[32;1m" }
  end

  def dp(message, color = :yellow)
    Rails.logger.debug { "\e[#{ansi color};1m" }
    Rails.logger.debug message
    Rails.logger.debug "\e[32;1m"
  end

  def dpp(message, color = :yellow)
    Rails.logger.debug { "\e[#{ansi color};1m" }
    Rails.logger.debug message
    Rails.logger.debug "\e[32;1m"
  end

  def dprint(message, color = :yellow)
    Rails.logger.debug { "\e[#{ansi color};1m#{message}\e[32;1m" }
  end
end
