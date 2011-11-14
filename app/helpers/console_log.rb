module ConsoleLog
  def dputs message, color=:yellow
    case color.to_sym
    when :gray    ; ansi = 30
    when :red     ; ansi = 31
    when :green   ; ansi = 32
    when :yellow  ; ansi = 33
    when :blue    ; ansi = 34
    when :pink    ; ansi = 35
    when :cyan    ; ansi = 36
    when :white   ; ansi = 37
    else          ; ansi = 35
    end

    puts "\e[#{ansi};1m#{message}\e[32;1m"
  end
end
