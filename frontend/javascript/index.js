import "$styles/index.css"
import "$styles/syntax-highlighting.css"
import "./search.js"

// Import all JavaScript & CSS files from src/_components
import components from "$components/**/*.{js,jsx,js.rb,css}"

// Writing page tabs
document.querySelectorAll(".writing-tab").forEach(tab => {
  tab.addEventListener("click", () => {
    document.querySelectorAll(".writing-tab").forEach(t => t.classList.remove("active"));
    document.querySelectorAll(".tab-panel").forEach(p => p.classList.remove("active"));
    tab.classList.add("active");
    document.getElementById(`tab-${tab.dataset.tab}`).classList.add("active");
  });
});