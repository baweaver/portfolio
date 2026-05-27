import TomSelect from "tom-select";
import "tom-select/dist/css/tom-select.css";

async function init() {
  const el = document.getElementById("post-search");
  if (!el) return;

  const res = await fetch("/search.json");
  const posts = await res.json();

  new TomSelect(el, {
    options: posts.map((p, i) => ({ value: p.url, text: p.title, date: p.date, order: i })),
    searchField: ["text"],
    sortField: [{ field: "$score", direction: "desc" }, { field: "order", direction: "asc" }],
    maxOptions: 10,
    placeholder: "Search posts...",
    render: {
      option: (data) => `<div><span class="ts-title">${data.text}</span><span class="ts-date">${data.date}</span></div>`,
      no_results: () => '<div class="no-results">No posts found</div>',
    },
    onChange: (value) => {
      if (value) window.location.href = value;
    },
  });
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", init);
} else {
  init();
}
