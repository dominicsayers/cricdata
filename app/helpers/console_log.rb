require 'pp'

module ConsoleLog
  def ansi(color)
    case color.to_sym
    when :gray then 30
    when :red then 31
    when :green then 32
    when :yellow then 33
    when :blue then 34
    when :pink then 35
    when :cyan then 36
    when :white then 37
    else; 35
    end
  end

  def dputs(message, color = :yellow)
    puts "\e[#{ansi color};1m#{message}\e[32;1m"
  end

  def dp(message, color = :yellow)
    print "\e[#{ansi color};1m"
    p message
    print "\e[32;1m"
  end

  def dpp(message, color = :yellow)
    print "\e[#{ansi color};1m"
    pp message
    print "\e[32;1m"
  end

  def dprint(message, color = :yellow)
    print "\e[#{ansi color};1m#{message}\e[32;1m"
  end
end
