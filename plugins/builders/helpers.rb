class Builders::Helpers < SiteBuilder
  def build
    helper "img", :img
    helper "link_to", :link_to_helper
    helper "nav_link", :nav_link
    helper "claim", :claim
  end

  # Usage: <%= claim("moving average count", 6) %>
  # Renders the value inline as plain text. The claim name must have a matching spec assertion.
  def claim(_name, value)
    value.to_s
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
end
