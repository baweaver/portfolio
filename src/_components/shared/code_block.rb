class Shared::CodeBlock < Bridgetown::Component
  def initialize(file:, segment: nil, lang: "ruby", unwrap: false, compact: false)
    @lang = lang
    @unwrap = unwrap
    @compact = compact
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

    lines = File.readlines(path).map { |l| l.gsub("\t", "    ") }
    result = segment ? extract_segment(lines, segment) : extract_all_segments(lines)
    raise "CodeBlock: segment '#{segment}' not found in #{file}" if segment && result.empty?
    @unwrap ? unwrap_method(result) : result
  end

  def extract_segment(lines, name)
    captures = []
    capturing = false
    current = []

    lines.each do |line|
      if line.match?(/^\s*(?:#|\/\/) segment:\s*#{Regexp.escape(name)}\s*$/)
        capturing = true
        current = []
      elsif line.match?(/^\s*(?:#|\/\/) end:\s*#{Regexp.escape(name)}\s*$/)
        captures << deindent(current).join.chomp if capturing
        capturing = false
      elsif capturing
        current << line
      end
    end

    separator = @compact ? "\n" : "\n\n"
    captures.join(separator)
  end

  def extract_all_segments(lines)
    in_segment = false
    captured = []

    lines.each do |line|
      if line.match?(/^\s*(?:#|\/\/) segment:\s*\S/)
        in_segment = true
        next
      elsif line.match?(/^\s*(?:#|\/\/) end:\s*\S/)
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
