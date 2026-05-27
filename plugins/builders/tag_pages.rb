class Builders::TagPages < SiteBuilder
  def build
    hook :site, :post_read do
      generate_tag_pages
    end
  end

  def generate_tag_pages
    tags = site.collections.posts.resources
      .select { |p| p.data.tags }
      .flat_map { |p| p.data.tags }
      .compact
      .map(&:strip)
      .reject(&:empty?)
      .tally
      .sort_by { |_, count| -count }

    tags.each do |tag, _count|
      slug = tag.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/-+$/, "")
      add_resource :pages, "tags/#{slug}.erb" do
        layout "default"
        title "Tagged: #{tag}"
        content <<~ERB
          <div class="page">
            <h1 class="page-title">Tagged: #{tag}</h1>
            <div class="post-list">
              <% collections.posts.resources.select { |p| p.data.tags&.include?("#{tag}") }.sort_by { |p| p.data.date }.reverse.each do |post| %>
                <a href="<%= relative_url post.relative_url %>" class="post-list-item">
                  <span class="post-list-meta"><%= post.data.date.strftime("%b %d, %Y") %></span>
                  <h2><%= post.data.title %></h2>
                </a>
              <% end %>
            </div>
          </div>
        ERB
      end
    end
  end
end
