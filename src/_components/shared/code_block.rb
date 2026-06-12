class Shared::CodeBlock < Bridgetown::Component
  def initialize(file:, segment: nil, lang: "ruby", unwrap: false)
    @lang = lang
    @unwrap = unwrap
    @code = extract_code(file, segment)
  end

  def highlighted
    formatter = Rouge::Formatters::HTML.new
    lexer = Rouge::Lexer.find(@lang) || Rouge::Lexers::PlainText.new
    formatter.format(lexer.lex(@code))
  end

  private

  def extract_code(file, segment)
    path = File.join(Bridgetown::Current.site.source, "_code", file)
    raise "CodeBlock: file not found: #{file}" unless File.exist?(path)

    lines = File.readlines(path)
    result = segment ? extract_segment(lines, segment) : extract_all_segments(lines)
    raise "CodeBlock: segment '#{segment}' not found in #{file}" if segment && result.empty?
    @unwrap ? unwrap_method(result) : result
  end

  def extract_segment(lines, name)
    capturing = false
    captured = []

    lines.each do |line|
      if line.match?(/^\s*# segment:\s*#{Regexp.escape(name)}\s*$/)
        capturing = true
      elsif line.match?(/^\s*# end:\s*#{Regexp.escape(name)}\s*$/)
        break
      elsif capturing
        captured << line
      end
    end

    deindent(captured).join.chomp
  end

  def extract_all_segments(lines)
    in_segment = false
    captured = []

    lines.each do |line|
      if line.match?(/^\s*# segment:\s*\S/)
        in_segment = true
        next
      elsif line.match?(/^\s*# end:\s*\S/)
        captured << "\n"
        next
      elsif in_segment
        captured << line
      end
    end

    deindent(captured).join.strip
  end

  def unwrap_method(code)
    lines = code.lines
    lines.shift while lines.first&.match?(/^\s*#/)
    lines.shift if lines.first&.match?(/^\s*def\s/)
    lines.pop if lines.last&.strip == "end"
    deindent(lines).join.chomp
  end

  def deindent(lines)
    non_blank = lines.reject { |l| l.strip.empty? }
    return lines if non_blank.empty?

    min_indent = non_blank.map { |l| l[/^ */].size }.min
    lines.map { |l| l.sub(/^ {0,#{min_indent}}/, "") }
  end
end
