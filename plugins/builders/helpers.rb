class Builders::Helpers < SiteBuilder
  REPO_URL = "https://github.com/baweaver/portfolio"
  SITE_URL = "https://baweaver.com"

  def build
    helper "img", :img
    helper "link_to", :link_to_helper
    helper "nav_link", :nav_link
    helper "claim", :claim
    helper "repo_link", :repo_link
    helper "repo_url", :repo_url
    helper "post_link", :post_link
    helper "post_url", :post_url_helper
    helper "site_link", :site_link
    helper "reading_time", :reading_time
  end

  # Usage: <%= claim("moving average count", 6) %>
  # Renders the value inline as plain text. The claim name must have a matching spec assertion.
  def claim(_name, value)
    value.to_s
  end

  # Usage: <%= repo_link "benchmark", "src/_code/beyond-enumerable-heaps/bench_shift.rb" %>
  # Generates a link to a file in the repo on the main branch.
  def repo_link(text, path)
    %(<a href="#{repo_url(path)}">#{text}</a>).strip
  end

  # Usage: <%= repo_url "src/_code/beyond-enumerable-heaps/bench_shift.rb" %>
  # Returns the raw URL. Handles leading slashes safely via URI.join.
  def repo_url(path)
    clean = path.delete_prefix("/")
    URI.join("#{REPO_URL}/", "blob/main/", clean).to_s
  end

  # Usage: <%= post_link "Last time", slug: "ozymandias-on-rails-the-pedestal-inscription" %>
  # Looks up a post by slug and generates a link to it.
  def post_link(text, slug:)
    url = find_post_url(slug)
    %(<a href="#{url}">#{text}</a>).strip
  end

  # Usage: <%= post_url slug: "ozymandias-on-rails-the-pedestal-inscription" %>
  # Returns the absolute URL for a post, looked up by slug.
  def post_url_helper(slug:)
    find_post_url(slug)
  end

  # Usage: <%= site_link "About", "/about" %>
  # Generates a full absolute link to any page on the site.
  def site_link(text, path)
    url = join_site_url(path)
    %(<a href="#{url}">#{text}</a>).strip
  end

  CODE_FENCE = /\A\s*```/
  PROSE_WPM = 238
  CODE_WPM = 100

  # Usage: <%= reading_time(resource) %>
  # Estimates reading time in minutes. Prose at 238 wpm, code blocks at 100 wpm.
  def reading_time(resource)
    content = resource.content.to_s
    prose_words = 0
    code_words = 0
    in_code_block = false

    content.each_line do |line|
      if line.match?(CODE_FENCE)
        in_code_block = !in_code_block
        next
      end

      words = line.split.size
      if in_code_block
        code_words += words
      else
        prose_words += words
      end
    end

    minutes = (prose_words / PROSE_WPM.to_f) + (code_words / CODE_WPM.to_f)
    minutes.ceil.clamp(1..)
  end

  # Usage: <%= img "/images/logo.png", alt: "Logo", class: "lantern" %>
  def img(path, alt: "", **attrs)
    attr_str = attrs.map { |k, v| %(#{k}="#{v}") }.join(" ")
    %(<img src="#{relative_url(path)}" alt="#{alt}" #{attr_str} />).strip
  end

  # Usage: <%= link_to "Home", "/" %>
  # Usage: <%= link_to "Writing", "/writing", class: "nav-item" %>
  def link_to_helper(text, path, **attrs)
    attr_str = attrs.map { |k, v| %(#{k}="#{v}") }.join(" ")
    %(<a href="#{relative_url(path)}" #{attr_str}>#{text}</a>).strip
  end

  # Usage: <%= nav_link "Home", "/", resource %>
  def nav_link(label, path, resource, icon: nil)
    active = if path == "/"
      resource.relative_url == "/"
    else
      resource.relative_url.start_with?(path)
    end
    cls = active ? "active" : ""
    %(
      <a href="#{relative_url(path)}" class="#{cls}">
        #{icon}
        <span>#{label}</span>
      </a>
    ).strip
  end

  private

  def relative_url(path)
    "#{site.base_path}#{path}"
  end

  def join_site_url(path)
    normalized = path.start_with?("/") ? path : "/#{path}"
    URI.join(SITE_URL, normalized).to_s
  end

  def find_post_url(slug)
    post = site.collections.posts.resources.find { |p| p.data.slug == slug }
    raise "post_link: no post found with slug '#{slug}'" unless post
    URI.join(SITE_URL, post.relative_url).to_s
  end
end
