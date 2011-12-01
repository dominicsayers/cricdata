require 'pp'

module ConsoleLog
  def ansi color
    case color.to_sym
    when :gray    ; 30
    when :red     ; 31
    when :green   ; 32
    when :yellow  ; 33
    when :blue    ; 34
    when :pink    ; 35
    when :cyan    ; 36
    when :white   ; 37
    else          ; 35
    end
  end

  def dputs message, color=:yellow
    puts "\e[#{ansi color};1m#{message}\e[32;1m"
  end

  def dp message, color=:yellow
    print "\e[#{ansi color};1m"
    p message
    print "\e[32;1m"
  end

  def dpp message, color=:yellow
    print "\e[#{ansi color};1m"
    pp message
    print "\e[32;1m"
  end

  def dprint message, color=:yellow
    print "\e[#{ansi color};1m#{message}\e[32;1m"
  end
end
